import Foundation

public struct MockDocumentationAdapter: DocumentationService {
    public var searchResults: [SearchResult]
    public var searchDiagnostics: SearchDiagnostics?
    public var resolveResult: ResolveResult?
    public var resolveErrorToThrow: DocumentationError?
    public var documentByID: [String: DocumentationContent]
    public var technologies: [Technology]
    public var errorToThrow: DocumentationError?
    public var version: String

    public init(
        searchResults: [SearchResult] = [],
        searchDiagnostics: SearchDiagnostics? = nil,
        resolveResult: ResolveResult? = nil,
        resolveErrorToThrow: DocumentationError? = nil,
        documentByID: [String: DocumentationContent] = [:],
        technologies: [Technology] = [],
        errorToThrow: DocumentationError? = nil,
        version: String = "1.0.0"
    ) {
        self.searchResults = searchResults
        self.searchDiagnostics = searchDiagnostics
        self.resolveResult = resolveResult
        self.resolveErrorToThrow = resolveErrorToThrow
        self.documentByID = documentByID
        self.technologies = technologies
        self.errorToThrow = errorToThrow
        self.version = version
    }

    public func search(query: String, config: DocumentationConfig) async throws -> [SearchResult] {
        if let errorToThrow { throw errorToThrow }
        return searchResults
    }

    public func searchDetailed(query: String, config: DocumentationConfig) async throws -> DocumentationSearchResponse {
        if let errorToThrow { throw errorToThrow }
        return DocumentationSearchResponse(results: searchResults, diagnostics: searchDiagnostics)
    }

    public func resolve(intent: ResolveIntent, config: DocumentationConfig) async throws -> ResolveResult {
        if let resolveErrorToThrow { throw resolveErrorToThrow }
        if let errorToThrow { throw errorToThrow }
        if let resolveResult { return resolveResult }
        throw DocumentationError.invalidResolveIntent(message: "mock resolve result is not configured")
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
