import Foundation

public protocol DocumentationService: Sendable {
    func search(query: String, config: DocumentationConfig) async throws -> [SearchResult]
    func searchDetailed(query: String, config: DocumentationConfig) async throws -> DocumentationSearchResponse
    func resolve(intent: ResolveIntent, config: DocumentationConfig) async throws -> ResolveResult
    func fetch(id: String, config: DocumentationConfig) async throws -> DocumentationContent
    func listTechnologies(config: DocumentationConfig) async throws -> [Technology]
    func getCoreVersion() -> String
}

public extension DocumentationService {
    func searchDetailed(query: String, config: DocumentationConfig) async throws -> DocumentationSearchResponse {
        DocumentationSearchResponse(results: try await search(query: query, config: config))
    }
}
