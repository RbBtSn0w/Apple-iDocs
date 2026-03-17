import Foundation

public protocol DocumentationService: Sendable {
    func search(query: String, config: DocumentationConfig) async throws -> [SearchResult]
    func fetch(id: String, config: DocumentationConfig) async throws -> DocumentationContent
    func listTechnologies(config: DocumentationConfig) async throws -> [Technology]
    func getCoreVersion() -> String
}
