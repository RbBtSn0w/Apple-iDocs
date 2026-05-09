import Foundation

public enum RetrievalSource: String, Sendable, Equatable {
    case cache
    case local
    case apple
    case sosumi
}

public struct DocumentationContent: Sendable, Equatable {
    public let title: String
    public let body: String
    public let metadata: [String: String]
    public let url: URL

    public init(title: String, body: String, metadata: [String: String] = [:], url: URL) {
        self.title = title
        self.body = body
        self.metadata = metadata
        self.url = url
    }
}

public struct SearchResult: Sendable, Equatable {
    public let id: String
    public let title: String
    public let snippet: String?
    public let technology: String
    public let source: RetrievalSource?

    public init(id: String, title: String, snippet: String?, technology: String, source: RetrievalSource? = nil) {
        self.id = id
        self.title = title
        self.snippet = snippet
        self.technology = technology
        self.source = source
    }
}

public struct SearchStageDiagnostic: Sendable, Codable, Equatable {
    public let name: String
    public let status: String
    public let durationMs: Double
    public let resultCount: Int
    public let reason: String?
    public let hint: String?

    enum CodingKeys: String, CodingKey {
        case name
        case status
        case durationMs = "duration_ms"
        case resultCount = "result_count"
        case reason
        case hint
    }

    public init(
        name: String,
        status: String,
        durationMs: Double,
        resultCount: Int,
        reason: String? = nil,
        hint: String? = nil
    ) {
        self.name = name
        self.status = status
        self.durationMs = durationMs
        self.resultCount = resultCount
        self.reason = reason
        self.hint = hint
    }
}

public struct SearchDiagnostics: Sendable, Codable, Equatable {
    public let stages: [SearchStageDiagnostic]

    public init(stages: [SearchStageDiagnostic]) {
        self.stages = stages
    }
}

public struct DocumentationSearchResponse: Sendable, Equatable {
    public let results: [SearchResult]
    public let diagnostics: SearchDiagnostics?

    public init(results: [SearchResult], diagnostics: SearchDiagnostics? = nil) {
        self.results = results
        self.diagnostics = diagnostics
    }
}

public struct Technology: Sendable, Equatable {
    public let name: String
    public let id: String
    public let category: String?

    public init(name: String, id: String, category: String?) {
        self.name = name
        self.id = id
        self.category = category
    }
}
