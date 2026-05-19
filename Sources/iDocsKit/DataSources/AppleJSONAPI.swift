import Foundation
import Logging

public actor AppleJSONAPI {
    private let logger = Logger(label: "com.snow.idocs-apple-api")
    private let session: any NetworkSession
    
    public init(session: any NetworkSession = URLSession.shared) {
        self.session = session
    }
    
    public func search(query: String) async throws -> [SearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else {
            return []
        }

        guard let url = URLHelpers.searchURL(query: query) else {
            return []
        }
        
        let data = try await fetchWithRetry(url: url)
        let decoder = JSONDecoder()
        let response = try decoder.decode(DocumentationIndexResponse.self, from: data)

        let indexedResults: [SearchResult] = response.references.values.compactMap { reference -> SearchResult? in
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

        if !indexedResults.isEmpty {
            return indexedResults
        }

        return try await searchTechnologyGraph(query: query)
    }
    
    public func fetchDoc(path: String) async throws -> DocCContent {
        try await fetchDocDetailed(path: path).content
    }

    public func fetchDocDetailed(path: String) async throws -> AppleDocCIngestionResult {
        guard let url = URLHelpers.dataURL(for: path) else {
            throw iDocsError.invalidURL
        }
        
        let data = try await fetchWithRetry(url: url)
        do {
            return try AppleDocCIngestion().normalize(data, requestedPath: path)
        } catch let ingestionError as AppleDocCIngestionError {
            throw ingestionError
        } catch {
            return AppleDocCIngestionResult(content: try JSONDecoder().decode(DocCContent.self, from: data), diagnostics: [])
        }
    }

    public func fetchTechnologies() async throws -> [Technology] {
        guard let url = URLHelpers.technologiesURL() else {
            throw iDocsError.invalidURL
        }

        let data = try await fetchWithRetry(url: url)
        return try parseTechnologies(from: data)
    }
    
    private func fetchWithRetry(url: URL, maxRetries: Int = 3) async throws -> Data {
        var lastError: Error?
        var delaySeconds: UInt64 = 1
        
        for attempt in 1...maxRetries {
            do {
                var request = URLRequest(url: url)
                request.setValue(UserAgentPool.random(), forHTTPHeaderField: "User-Agent")
                
                let (data, response) = try await session.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        return data
                    } else if httpResponse.statusCode == 403 || httpResponse.statusCode == 429 {
                        logger.warning("Attempt \(attempt) failed with status code \(httpResponse.statusCode). Retrying...")
                    } else {
                        throw iDocsError.httpError(statusCode: httpResponse.statusCode)
                    }
                }
            } catch {
                lastError = error
                logger.error("Attempt \(attempt) failed with error: \(error.localizedDescription)")
            }
            
            if attempt < maxRetries {
                try await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
                delaySeconds *= 2
            }
        }
        
        throw lastError ?? iDocsError.maxRetriesReached
    }

    private nonisolated func documentKind(kind: String?, role: String?, type: String?) -> DocumentKind {
        let value = (kind ?? role ?? type ?? "").lowercased()
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
            return .overview
        }
    }

    private func relevanceScore(for query: String, title: String, abstract: String?, path: String) -> Double {
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

    private func searchTechnologyGraph(query: String) async throws -> [SearchResult] {
        let intent = SearchQueryIntent(query)
        let technologies = try await fetchTechnologies()
        var matchedTechnologies = technologies.filter { intent.matches(technology: $0) }
        if matchedTechnologies.isEmpty && !intent.requiredSymbols.isEmpty {
            matchedTechnologies = technologies
        }
        let candidateTechnologies = matchedTechnologies
            .compactMap { technologyRootPath(for: $0) }

        guard !candidateTechnologies.isEmpty else {
            return []
        }

        var results: [SearchResult] = []
        var firstFailure: Error?

        await withTaskGroup(of: TechnologyGraphLookupResult.self) { group in
            for rootPath in candidateTechnologies {
                group.addTask { [self] in
                    do {
                        let matches = try await searchTechnologyReferences(rootPath: rootPath, intent: intent)
                        return .hit(matches)
                    } catch {
                        if isTechnologyGraphMiss(error) {
                            return .miss(path: rootPath, errorDescription: error.localizedDescription)
                        }
                        return .failure(error)
                    }
                }
            }

            for await lookupResult in group {
                switch lookupResult {
                case .hit(let matches):
                    results.append(contentsOf: matches)
                case .miss(let path, let errorDescription):
                    logger.debug("Apple technology graph missed: \(path) (\(errorDescription))")
                case .failure(let error):
                    firstFailure = firstFailure ?? error
                }
            }
        }

        if results.isEmpty, let firstFailure {
            throw firstFailure
        }

        return SearchResultRanker(intent: intent).rankedRemoteResults(results)
    }

    private func searchTechnologyReferences(rootPath: String, intent: SearchQueryIntent) async throws -> [SearchResult] {
        guard let url = URLHelpers.dataURL(for: rootPath) else {
            throw iDocsError.invalidURL
        }

        let data = try await fetchWithRetry(url: url)
        let graph = try JSONDecoder().decode(TechnologyGraphSearchDocument.self, from: data)
        let matches: [SearchResult] = (graph.references ?? [:]).values.compactMap { reference in
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

        return SearchResultRanker(intent: intent)
            .rankedRemoteResults(matches)
            .prefix(50)
            .map { $0 }
    }

    private func technologyRootPath(for technology: Technology) -> String? {
        let normalized = URLHelpers.normalizePath(technology.url)
        guard normalized.hasPrefix("/documentation/") else {
            return nil
        }

        let components = normalized.split(separator: "/")
        guard components.count >= 2 else {
            return nil
        }

        return "/documentation/\(components[1])"
    }

    private nonisolated func isTechnologyGraphMiss(_ error: Error) -> Bool {
        switch error {
        case iDocsError.invalidURL:
            return true
        case iDocsError.httpError(let statusCode):
            return statusCode == 404
        default:
            return false
        }
    }

    private func parseTechnologies(from data: Data) throws -> [Technology] {
        let decoder = JSONDecoder()

        if let legacy = try? decoder.decode(TechnologiesResponse.self, from: data) {
            return legacy.technologies
        }

        let modern = try decoder.decode(TechnologyCatalogResponse.self, from: data)
        var results: [Technology] = []

        for section in modern.sections ?? [] {
            for group in section.groups ?? [] {
                for item in group.technologies ?? [] {
                    guard let name = item.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !name.isEmpty else {
                        continue
                    }

                    let path = item.url
                        ?? item.destination?.identifier.flatMap(pathFromDocIdentifier)
                        ?? "/documentation/\(name)"

                    let category = item.kind
                        ?? item.tags?.first
                        ?? "technology"

                    results.append(Technology(name: name, url: path, kind: category))
                }
            }
        }

        return results
    }

    private func pathFromDocIdentifier(_ identifier: String) -> String? {
        guard let markerRange = identifier.range(of: "/documentation/") else {
            return nil
        }
        return String(identifier[markerRange.lowerBound...])
    }
}

private enum TechnologyGraphLookupResult: Sendable {
    case hit([SearchResult])
    case miss(path: String, errorDescription: String)
    case failure(any Error)
}

// MARK: - API Response Types

private struct TechnologyGraphSearchDocument: Codable {
    let references: [String: DocumentationReference]?
}

private struct TechnologiesResponse: Codable {
    let technologies: [Technology]
}

private struct TechnologyCatalogResponse: Codable {
    let sections: [TechnologySection]?
}

private struct TechnologySection: Codable {
    let groups: [TechnologyGroup]?
}

private struct TechnologyGroup: Codable {
    let technologies: [TechnologyItem]?
}

private struct TechnologyItem: Codable {
    let title: String?
    let tags: [String]?
    let kind: String?
    let url: String?
    let destination: TechnologyDestination?
}

private struct TechnologyDestination: Codable {
    let identifier: String?
}

public struct Technology: Codable, Sendable {
    public let name: String
    public let url: String
    public let kind: String
}

private struct DocumentationIndexResponse: Codable {
    let references: [String: DocumentationReference]
}

private struct DocumentationReference: Codable {
    let title: String?
    let type: String?
    let role: String?
    let kind: String?
    let url: String?
    let abstract: [InlineText]?

    var abstractText: String? {
        let text = abstract?
            .compactMap { $0.text?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return text?.isEmpty == false ? text : nil
    }
}

private struct InlineText: Codable {
    let text: String?
}

// MARK: - Custom Errors

public enum iDocsError: Error {
    case httpError(statusCode: Int)
    case maxRetriesReached
    case invalidURL
    case invalidResponse
    case emptyResponse
    case unsupportedSourceType(path: String, sourceKind: AppleSourceKind, attempts: [FetchSourceAttempt])
    case aggregateFetchFailure(path: String, attempts: [FetchSourceAttempt])

    public var fetchAttempts: [FetchSourceAttempt] {
        switch self {
        case .unsupportedSourceType(_, _, let attempts),
             .aggregateFetchFailure(_, let attempts):
            return attempts
        case .httpError, .maxRetriesReached, .invalidURL, .invalidResponse, .emptyResponse:
            return []
        }
    }

    public var reason: String {
        switch self {
        case .httpError(let statusCode):
            return "http_\(statusCode)"
        case .maxRetriesReached:
            return "max_retries_reached"
        case .invalidURL:
            return "invalid_url"
        case .invalidResponse:
            return "invalid_response"
        case .emptyResponse:
            return "empty_body"
        case .unsupportedSourceType:
            return "unsupported_source_type"
        case .aggregateFetchFailure(_, let attempts):
            return attempts.last?.reason ?? "fetch_failed"
        }
    }
}
