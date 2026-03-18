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

        return response.references.values.compactMap { reference in
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
                source: .remote,
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
        let decoder = JSONDecoder()
        let response = try decoder.decode(TechnologiesResponse.self, from: data)
        return response.technologies
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

    private func documentKind(kind: String?, role: String?, type: String?) -> DocumentKind {
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
}

// MARK: - API Response Types

private struct TechnologiesResponse: Codable {
    let technologies: [Technology]
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
}
