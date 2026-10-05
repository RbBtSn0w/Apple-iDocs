import Foundation
import Logging
import iDocsTelemetry

public struct AppleRemoteSearchCrawler: Sendable {
    private let logger = Logger(label: "com.snow.idocs-apple-search-crawler")
    public let httpClient: AppleDocumentationHTTPClient
    public let profile: SearchRelevanceProfile

    public init(
        httpClient: AppleDocumentationHTTPClient,
        profile: SearchRelevanceProfile = .standard
    ) {
        self.httpClient = httpClient
        self.profile = profile
    }

    public func search(
        query: String,
        fetchTechnologies: @Sendable () async throws -> [Technology]
    ) async throws -> [SearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else {
            return []
        }

        if let data = try await httpClient.fetchSearchData(query: query) {
            let decoder = JSONDecoder()
            if let response = try? decoder.decode(DocumentationIndexResponse.self, from: data) {
                let indexedResults = parseIndexedResults(response: response, normalizedQuery: normalizedQuery)
                if !indexedResults.isEmpty {
                    return indexedResults
                }
            }
        }

        let technologies = try await fetchTechnologies()
        return try await searchTechnologyGraph(query: query, technologies: technologies)
    }

    public func parseIndexedResults(response: DocumentationIndexResponse, normalizedQuery: String) -> [SearchResult] {
        response.references.values.compactMap { reference -> SearchResult? in
            guard let title = reference.title,
                  let url = reference.url else {
                return nil
            }

            let abstract = reference.abstractText
            let haystack = "\(title) \(abstract ?? "") \(url)".lowercased()
            guard haystack.contains(normalizedQuery) else {
                return nil
            }

            let score = relevanceScore(for: normalizedQuery, title: title, abstract: abstract, path: url)
            return SearchResult(
                title: title,
                abstract: abstract,
                path: url,
                kind: documentKind(kind: reference.kind, role: reference.role, type: reference.type),
                source: .apple,
                relevance: score
            )
        }
        .sorted {
            let left = $0.relevance ?? 0
            let right = $1.relevance ?? 0
            if left == right { return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            return left > right
        }
        .prefix(50)
        .map { $0 }
    }

    public func searchTechnologyGraph(query: String, technologies: [Technology]) async throws -> [SearchResult] {
        let intent = SearchQueryIntent(query, profile: profile)
        var matchedTechnologies = technologies.filter { intent.matches(technology: $0) }
        if matchedTechnologies.isEmpty && !intent.requiredSymbols.isEmpty {
            let priorityTechnologies = ["swiftui", "uikit", "appkit", "foundation", "xcode", "swiftdata", "coredata", "combine"]
            let filtered = technologies.compactMap { tech -> (Technology, Int)? in
                let norm = URLHelpers.normalizePath(tech.url).lowercased()
                guard let idx = priorityTechnologies.firstIndex(where: { norm.contains($0) }) else {
                    return nil
                }
                return (tech, idx)
            }
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }
            matchedTechnologies = filtered.isEmpty ? Array(technologies.prefix(15)) : filtered
        }
        let candidateTechnologies = matchedTechnologies
            .compactMap { technologyRootPath(for: $0) }

        guard !candidateTechnologies.isEmpty else {
            return []
        }

        var results: [SearchResult] = []
        var firstFailure: Error?

        try Task.checkCancellation()

        await withTaskGroup(of: TechnologyGraphLookupResult.self) { group in
            for rootPath in candidateTechnologies {
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
                group.addTask {
                    guard !Task.isCancelled else {
                        return .failure(CancellationError())
                    }
                    do {
                        let matches = try await self.searchTechnologyReferences(rootPath: rootPath, intent: intent)
                        return .hit(matches)
                    } catch {
                        if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                            return .failure(CancellationError())
                        }
                        if self.isTechnologyGraphMiss(error) {
                            return .miss(path: rootPath, errorDescription: error.localizedDescription)
                        }
                        return .failure(error)
                    }
                }
            }

            for await lookupResult in group {
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
                switch lookupResult {
                case .hit(let matches):
                    results.append(contentsOf: matches)
                case .miss(let path, let errorDescription):
                    logger.debug("Apple technology graph missed: \(path) (\(errorDescription))")
                case .failure(let error):
                    if error is CancellationError {
                        group.cancelAll()
                    }
                    firstFailure = firstFailure ?? error
                }
            }
        }

        if Task.isCancelled {
            throw CancellationError()
        }

        if results.isEmpty, let firstFailure {
            throw firstFailure
        }

        return SearchResultRanker(intent: intent).rankedRemoteResults(results, limit: 50)
    }

    func searchTechnologyReferences(rootPath: String, intent: SearchQueryIntent) async throws -> [SearchResult] {
        guard let url = URLHelpers.dataURL(for: rootPath) else {
            throw iDocsError.invalidURL
        }

        let data = try await httpClient.fetchWithRetry(url: url)
        let graph = try JSONDecoder().decode(TechnologyGraphSearchDocument.self, from: data)
        var matches: [SearchResult] = (graph.references ?? [:]).values.compactMap { reference in
            guard let title = reference.title,
                  let path = reference.url,
                  intent.acceptsCandidate(title: title, path: path, abstract: reference.abstractText) else {
                return nil
            }

            let sourceKind = AppleSourceKind(path: path)
            let kind = documentKind(kind: reference.kind, role: reference.role, type: reference.type)
            let matchScope = SearchResult.inferMatchScope(path: path, kind: kind)
            let score = intent.score(
                title: title,
                path: path,
                abstract: reference.abstractText,
                sourceKind: sourceKind,
                fetchSupported: sourceKind.fetchSupportedByIDocs,
                matchScope: matchScope
            )

            guard score > 0 else {
                return nil
            }

            return SearchResult(
                title: title,
                abstract: reference.abstractText,
                path: path,
                kind: kind,
                source: .apple,
                relevance: score,
                sourceKind: sourceKind,
                fetchSupported: sourceKind.fetchSupportedByIDocs,
                matchScope: matchScope
            )
        }

        let xcodeRoot = DocumentationPath.make("xcode")
        let xcodePrefix = xcodeRoot + "/"
        if rootPath.lowercased() == xcodeRoot {
            let candidateGroups = (graph.references ?? [:]).values.filter { ref in
                guard ref.role == "collectionGroup", let url = ref.url, url.lowercased().hasPrefix(xcodePrefix) else {
                    return false
                }
                return true
            }

            let scoredGroups: [(ref: DocumentationReference, score: Double, url: String)] = candidateGroups.compactMap { ref in
                guard let url = ref.url else { return nil }
                let title = ref.title ?? ""
                let abstract = ref.abstractText ?? ""
                var score = intent.score(
                    title: title,
                    path: url,
                    abstract: abstract,
                    sourceKind: .documentation,
                    fetchSupported: true,
                    matchScope: .module
                )

                let queryStems = Set(intent.tokenStems)
                score += intent.profile.boost(forSubgroupURL: url, queryStems: queryStems)

                guard score > 0 else { return nil }
                return (ref: ref, score: score, url: url)
            }

            let sortedGroups = scoredGroups.sorted { left, right in
                if left.score != right.score {
                    return left.score > right.score
                }
                return left.url < right.url
            }

            for scored in sortedGroups.prefix(3) {
                if Task.isCancelled {
                    throw CancellationError()
                }
                do {
                    let subMatches = try await searchTechnologyReferences(rootPath: scored.url, intent: intent)
                    matches.append(contentsOf: subMatches)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    logger.debug("Failed to search Xcode subGroup \(scored.url): \(error.localizedDescription)")
                }
            }
        }

        return SearchResultRanker(intent: intent)
            .rankedRemoteResults(matches, limit: 50)
    }

    public func technologyRootPath(for technology: Technology) -> String? {
        let normalized = URLHelpers.normalizePath(technology.url)
        guard normalized.hasPrefix(DocumentationPath.prefix) else {
            return nil
        }

        let components = normalized.split(separator: "/")
        guard components.count >= 2 else {
            return nil
        }

        return DocumentationPath.make(String(components[1]))
    }

    public func isTechnologyGraphMiss(_ error: Error) -> Bool {
        switch error {
        case iDocsError.invalidURL:
            return true
        case iDocsError.httpError(let statusCode):
            return statusCode == 404
        default:
            return false
        }
    }

    public func documentKind(kind: String?, role: String?, type: String?) -> DocumentKind {
        let candidates = [kind, type, role].compactMap { $0?.lowercased() }
        for value in candidates {
            switch value {
            case "framework", "module":
                return .framework
            case "class":
                return .class
            case "struct", "structure":
                return .structure
            case "protocol":
                return .protocol
            case "enum", "enumeration":
                return .enumeration
            case "function":
                return .function
            case "property":
                return .property
            case "typealias":
                return .typealias
            case "associatedtype":
                return .associatedtype
            case "operator":
                return .operator
            case "macro":
                return .macro
            case "variable":
                return .variable
            case "initializer", "init":
                return .initializer
            case "instancetype", "instancemethod":
                return .instanceMethod
            case "typemethod":
                return .typeMethod
            case "instanceproperty":
                return .instanceProperty
            case "typeproperty":
                return .typeProperty
            case "article":
                return .article
            case "sample code", "samplecode", "sample-code":
                return .sampleCode
            default:
                continue
            }
        }
        return .overview
    }

    public func relevanceScore(for query: String, title: String, abstract: String?, path: String) -> Double {
        let q = query.lowercased()
        let t = title.lowercased()
        let a = (abstract ?? "").lowercased()
        let p = path.lowercased()
        var score = 0.0

        if t == q { score += 120 }
        if t.hasPrefix(q) { score += 80 }
        if t.contains(q) { score += 40 }
        if p.contains("/\(q)") || p.hasSuffix("/\(q)") { score += 30 }
        if p.contains(q) { score += 20 }
        if a.contains(q) { score += 10 }

        // Slightly prefer shorter titles for the same token match.
        score -= Double(title.count) * 0.01
        return score
    }
}

private enum TechnologyGraphLookupResult: Sendable {
    case hit([SearchResult])
    case miss(path: String, errorDescription: String)
    case failure(any Error)
}

struct TechnologyGraphSearchDocument: Codable {
    let references: [String: DocumentationReference]?
}

public struct DocumentationIndexResponse: Codable, Sendable {
    public let references: [String: DocumentationReference]

    public init(references: [String: DocumentationReference]) {
        self.references = references
    }
}

public struct DocumentationReference: Codable, Sendable {
    public let title: String?
    public let type: String?
    public let role: String?
    public let kind: String?
    public let url: String?
    public let abstract: [InlineText]?

    public init(
        title: String? = nil,
        type: String? = nil,
        role: String? = nil,
        kind: String? = nil,
        url: String? = nil,
        abstract: [InlineText]? = nil
    ) {
        self.title = title
        self.type = type
        self.role = role
        self.kind = kind
        self.url = url
        self.abstract = abstract
    }

    public var abstractText: String? {
        let text = abstract?
            .compactMap { $0.text?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return text?.isEmpty == false ? text : nil
    }
}

public struct InlineText: Codable, Sendable {
    public let type: String?
    public let text: String?

    public init(text: String?, type: String? = nil) {
        self.text = text
        self.type = type
    }
}
