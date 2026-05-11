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

        return try await searchDirectAppleDocs(query: query)
    }
    
    public func fetchDoc(path: String) async throws -> DocCContent {
        guard let url = URLHelpers.dataURL(for: path) else {
            throw iDocsError.invalidURL
        }
        
        let data = try await fetchWithRetry(url: url)
        let decoder = JSONDecoder()
        return try decoder.decode(DocCContent.self, from: data)
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

    private func searchDirectAppleDocs(query: String) async throws -> [SearchResult] {
        var results: [SearchResult] = []
        var firstFailure: Error?

        await withTaskGroup(of: DirectLookupResult.self) { group in
            for candidate in uniqueDirectLookupCandidates(for: query) {
                group.addTask { [self] in
                    do {
                        let summary = try await fetchDirectDocSummary(path: candidate.path)
                        return .hit(
                            SearchResult(
                                title: summary.metadata.title,
                                abstract: summary.abstractText,
                                path: candidate.path,
                                kind: documentKind(kind: nil, role: summary.metadata.role, type: nil),
                                source: .apple,
                                relevance: candidate.relevance
                            )
                        )
                    } catch {
                        if isDirectLookupMiss(error) {
                            return .miss(path: candidate.path, errorDescription: error.localizedDescription)
                        }
                        return .failure(error)
                    }
                }
            }

            for await lookupResult in group {
                switch lookupResult {
                case .hit(let result):
                    results.append(result)
                case .miss(let path, let errorDescription):
                    logger.debug("Direct Apple lookup candidate missed: \(path) (\(errorDescription))")
                case .failure(let error):
                    firstFailure = firstFailure ?? error
                }
            }
        }

        if results.isEmpty, let firstFailure {
            throw firstFailure
        }

        return results.sorted {
            let left = $0.relevance ?? 0
            let right = $1.relevance ?? 0
            if left == right { return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            return left > right
        }
    }

    private func fetchDirectDocSummary(path: String) async throws -> DirectDocSummary {
        guard let url = URLHelpers.dataURL(for: path) else {
            throw iDocsError.invalidURL
        }

        let data = try await fetchWithRetry(url: url)
        return try JSONDecoder().decode(DirectDocSummary.self, from: data)
    }

    private func uniqueDirectLookupCandidates(for query: String) -> [DirectLookupCandidate] {
        var seenPaths = Set<String>()
        return directLookupCandidates(for: query).filter { candidate in
            seenPaths.insert(candidate.path).inserted
        }
    }

    private func directLookupCandidates(for query: String) -> [DirectLookupCandidate] {
        let normalized = normalizeSearchText(query)
        let orderedTokens = searchTokens(query)
        let tokens = Set(orderedTokens.map { $0.lowercased() })
        let hasKnownDirectSymbol = normalized.contains("navigationsplitview")
            || normalized.contains("inspectorcolumnwidth")
        var candidates: [DirectLookupCandidate] = []

        func append(_ path: String, relevance: Double) {
            candidates.append(DirectLookupCandidate(path: path, relevance: relevance))
        }

        if normalized.contains("navigationsplitview") {
            append("/documentation/swiftui/navigationsplitview", relevance: 180)
        }

        if normalized.contains("inspectorcolumnwidth") {
            append("/documentation/swiftui/view/inspectorcolumnwidth(min:ideal:max:)", relevance: 180)
        }

        if tokens.contains("split") && (tokens.contains("view") || tokens.contains("views")) {
            append("/design/human-interface-guidelines/split-views", relevance: 170)
        }

        if tokens.contains("sidebar") || tokens.contains("sidebars") {
            append("/design/human-interface-guidelines/sidebars", relevance: 140)
        }

        if tokens.contains("swiftui") && !hasKnownDirectSymbol {
            for token in orderedTokens where isLikelySwiftSymbolToken(token) {
                append("/documentation/swiftui/\(token.lowercased())", relevance: 120)
            }
        }

        return candidates
    }

    private func normalizeSearchText(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func searchTokens(_ text: String) -> [String] {
        text.split { character in
            !character.isLetter && !character.isNumber
        }
        .map { String($0) }
        .filter { !$0.isEmpty }
    }

    private func isLikelySwiftSymbolToken(_ token: String) -> Bool {
        let normalized = token.lowercased()
        let excluded = [
            "swiftui", "macos", "ios", "ipados", "watchos", "tvos",
            "visionos", "sidebar", "sidebars", "detail", "inspector",
            "split", "view", "views", "ispresented"
        ]
        guard !excluded.contains(normalized) else { return false }
        return token.rangeOfCharacter(from: .uppercaseLetters) != nil
            || normalized.contains("view")
            || normalized.contains("width")
    }

    private nonisolated func isDirectLookupMiss(_ error: Error) -> Bool {
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

private struct DirectLookupCandidate {
    let path: String
    let relevance: Double
}

private enum DirectLookupResult: Sendable {
    case hit(SearchResult)
    case miss(path: String, errorDescription: String)
    case failure(any Error)
}

// MARK: - API Response Types

private struct DirectDocSummary: Codable {
    let metadata: DirectDocMetadata
    let abstract: [InlineText]?

    var abstractText: String? {
        let text = abstract?
            .compactMap { $0.text?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return text?.isEmpty == false ? text : nil
    }
}

private struct DirectDocMetadata: Codable {
    let title: String
    let role: String?
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
    case unsupportedSourceType(path: String, sourceKind: AppleSourceKind, attempts: [FetchSourceAttempt])
    case aggregateFetchFailure(path: String, attempts: [FetchSourceAttempt])

    public var fetchAttempts: [FetchSourceAttempt] {
        switch self {
        case .unsupportedSourceType(_, _, let attempts),
             .aggregateFetchFailure(_, let attempts):
            return attempts
        case .httpError, .maxRetriesReached, .invalidURL:
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
        case .unsupportedSourceType:
            return "unsupported_source_type"
        case .aggregateFetchFailure(_, let attempts):
            return attempts.last?.reason ?? "fetch_failed"
        }
    }
}
