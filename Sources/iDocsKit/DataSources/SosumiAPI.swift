import Foundation
import Logging

public actor SosumiAPI {
    private let logger = Logger(label: "com.snow.idocs-sosumi-api")
    private let session: any NetworkSession

    public init(session: any NetworkSession = URLSession.shared) {
        self.session = session
    }

    public func search(query: String) async throws -> [SearchResult] {
        guard let url = URLHelpers.sosumiSearchURL(query: query) else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(UserAgentPool.random(), forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw iDocsError.maxRetriesReached
        }
        guard http.statusCode == 200 else {
            throw iDocsError.httpError(statusCode: http.statusCode)
        }

        let payload = try JSONDecoder().decode(SosumiSearchResponse.self, from: data)
        return payload.results.map { item in
            SearchResult(
                title: item.title,
                abstract: item.description,
                path: normalizePath(item.url),
                kind: kind(from: item.type),
                source: .sosumi
            )
        }
    }

    public func fetchMarkdown(path: String) async throws -> String {
        guard let url = URLHelpers.sosumiFetchURL(for: path) else {
            throw iDocsError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("text/markdown, text/plain;q=0.9", forHTTPHeaderField: "Accept")
        request.setValue(UserAgentPool.random(), forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw iDocsError.maxRetriesReached
        }
        guard http.statusCode == 200 else {
            logger.warning("Sosumi fetch returned status \(http.statusCode) for \(path)")
            throw iDocsError.httpError(statusCode: http.statusCode)
        }

        guard let markdown = String(data: data, encoding: .utf8), !markdown.isEmpty else {
            throw iDocsError.maxRetriesReached
        }
        return markdown
    }

    private func normalizePath(_ rawURL: String) -> String {
        if rawURL.hasPrefix("/") {
            return rawURL
        }
        if let url = URL(string: rawURL), !url.path.isEmpty {
            return url.path
        }
        return rawURL
    }

    private func kind(from type: String) -> DocumentKind {
        switch type.lowercased() {
        case "documentation":
            return .overview
        case "general":
            return .article
        default:
            return .overview
        }
    }
}

private struct SosumiSearchResponse: Codable {
    let query: String
    let results: [SosumiSearchItem]
}

private struct SosumiSearchItem: Codable {
    let title: String
    let url: String
    let description: String?
    let type: String
}
