import Foundation

public struct MockDocumentationAdapter: DocumentationService {
    public var searchResults: [SearchResult]
    public var documentByID: [String: DocumentationContent]
    public var technologies: [Technology]
    public var errorToThrow: DocumentationError?
    public var version: String

    public init(
        searchResults: [SearchResult] = [],
        documentByID: [String: DocumentationContent] = [:],
        technologies: [Technology] = [],
        errorToThrow: DocumentationError? = nil,
        version: String = "1.0.0"
    ) {
        self.searchResults = searchResults
        self.documentByID = documentByID
        self.technologies = technologies
        self.errorToThrow = errorToThrow
        self.version = version
    }

    public func search(query: String, config: DocumentationConfig) async throws -> [SearchResult] {
        if let errorToThrow { throw errorToThrow }
        return searchResults
    }

    public func fetch(id: String, config: DocumentationConfig) async throws -> DocumentationContent {
        if let errorToThrow { throw errorToThrow }
        guard let content = documentByID[id] else {
            throw DocumentationError.notFound(id: id)
        }
        return content
    }

    public func listTechnologies(config: DocumentationConfig) async throws -> [Technology] {
        if let errorToThrow { throw errorToThrow }
        guard let category = config.technologyCategoryFilter?.trimmingCharacters(in: .whitespacesAndNewlines),
              !category.isEmpty else {
            return technologies
        }

        return technologies.filter { technology in
            technology.category?.localizedCaseInsensitiveContains(category) == true
        }
    }

    public func getCoreVersion() -> String {
        version
    }
}
