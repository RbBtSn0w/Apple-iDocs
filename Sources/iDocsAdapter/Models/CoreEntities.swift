import Foundation

public enum RetrievalSource: String, Sendable, Equatable {
    case cache
    case local
    case apple
    case help
    case sosumi
    case unsupported
}

public struct FetchAttemptDiagnostic: Sendable, Codable, Equatable {
    public let source: String
    public let status: String
    public let reason: String?
    public let contentType: String?
    public let statusCode: Int?
    public let hint: String?

    enum CodingKeys: String, CodingKey {
        case source
        case status
        case reason
        case contentType = "content_type"
        case statusCode = "status_code"
        case hint
    }

    public init(
        source: String,
        status: String,
        reason: String? = nil,
        contentType: String? = nil,
        statusCode: Int? = nil,
        hint: String? = nil
    ) {
        self.source = source
        self.status = status
        self.reason = reason
        self.contentType = contentType
        self.statusCode = statusCode
        self.hint = hint
    }
}

public struct DocumentationContent: Sendable, Equatable {
    public let title: String
    public let body: String
    public let metadata: [String: String]
    public let url: URL
    public let fetchDiagnostics: [FetchAttemptDiagnostic]?

    public init(
        title: String,
        body: String,
        metadata: [String: String] = [:],
        url: URL,
        fetchDiagnostics: [FetchAttemptDiagnostic]? = nil
    ) {
        self.title = title
        self.body = body
        self.metadata = metadata
        self.url = url
        self.fetchDiagnostics = fetchDiagnostics
    }
}

public struct SearchResult: Sendable, Equatable {
    public let id: String
    public let title: String
    public let snippet: String?
    public let technology: String
    public let source: RetrievalSource?
    public let sourceKind: String
    public let fetchSupported: Bool
    public let fetchSupportReason: String?
    public let matchScope: String
    public let queryAttempt: String?

    public init(
        id: String,
        title: String,
        snippet: String?,
        technology: String,
        source: RetrievalSource? = nil,
        sourceKind: String = "documentation",
        fetchSupported: Bool = true,
        fetchSupportReason: String? = nil,
        matchScope: String = "path",
        queryAttempt: String? = nil
    ) {
        self.id = id
        self.title = title
        self.snippet = snippet
        self.technology = technology
        self.source = source
        self.sourceKind = sourceKind
        self.fetchSupported = fetchSupported
        self.fetchSupportReason = fetchSupportReason
        self.matchScope = matchScope
        self.queryAttempt = queryAttempt
    }
}

public struct SearchStageDiagnostic: Sendable, Codable, Equatable {
    public let name: String
    public let status: String
    public let durationMs: Double
    public let resultCount: Int
    public let reason: String?
    public let hint: String?
    public let queryAttempt: String?

    enum CodingKeys: String, CodingKey {
        case name
        case status
        case durationMs = "duration_ms"
        case resultCount = "result_count"
        case reason
        case hint
        case queryAttempt = "query_attempt"
    }

    public init(
        name: String,
        status: String,
        durationMs: Double,
        resultCount: Int,
        reason: String? = nil,
        hint: String? = nil,
        queryAttempt: String? = nil
    ) {
        self.name = name
        self.status = status
        self.durationMs = durationMs
        self.resultCount = resultCount
        self.reason = reason
        self.hint = hint
        self.queryAttempt = queryAttempt
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
