import Foundation
import Logging
import iDocsTelemetry

public actor AppleJSONAPI {
    private let logger = Logger(label: "com.snow.idocs-apple-api")
    public let httpClient: AppleDocumentationHTTPClient
    public let crawler: AppleRemoteSearchCrawler

    public init(session: any NetworkSession = URLSession.shared, retryDelayNanoseconds: UInt64? = nil) {
        let client = AppleDocumentationHTTPClient(session: session, retryDelayNanoseconds: retryDelayNanoseconds)
        self.httpClient = client
        self.crawler = AppleRemoteSearchCrawler(httpClient: client)
    }

    public init(httpClient: AppleDocumentationHTTPClient, crawler: AppleRemoteSearchCrawler? = nil) {
        self.httpClient = httpClient
        self.crawler = crawler ?? AppleRemoteSearchCrawler(httpClient: httpClient)
    }

    public func search(query: String) async throws -> [SearchResult] {
        try await crawler.search(query: query) { [self] in
            try await self.fetchTechnologies()
        }
    }

    public func fetchDoc(path: String) async throws -> DocCContent {
        try await fetchDocDetailed(path: path).content
    }

    public func fetchDocDetailed(path: String) async throws -> AppleDocCIngestionResult {
        let data = try await httpClient.fetchData(for: path)
        do {
            return try AppleDocCIngestion().normalize(data, requestedPath: path)
        } catch let ingestionError as AppleDocCIngestionError {
            throw ingestionError
        } catch {
            return AppleDocCIngestionResult(content: try JSONDecoder().decode(DocCContent.self, from: data), diagnostics: [])
        }
    }

    public func fetchTechnologies() async throws -> [Technology] {
        let data = try await httpClient.fetchTechnologiesData()
        return try parseTechnologies(from: data)
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
                        ?? DocumentationPath.make(name)

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
        guard let markerRange = identifier.range(of: DocumentationPath.prefix) else {
            return nil
        }
        return String(identifier[markerRange.lowerBound...])
    }
}

// MARK: - API Response Types

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

    public init(name: String, url: String, kind: String) {
        self.name = name
        self.url = url
        self.kind = kind
    }
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
