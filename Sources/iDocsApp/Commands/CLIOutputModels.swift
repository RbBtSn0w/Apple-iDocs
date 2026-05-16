import Foundation

public enum CLIOutputFormat: String, Sendable {
    case text
    case json
}

public enum CLIExitCategory: String, Codable, Sendable {
    case ok = "OK"
    case notFound = "NOT_FOUND"
    case network = "NETWORK"
    case parsing = "PARSING"
    case unauthorized = "UNAUTHORIZED"
    case config = "CONFIG"
    case versionMismatch = "VERSION_MISMATCH"
    case internalError = "INTERNAL"
}

public struct CLISearchResultPayload: Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let snippet: String?
    public let technology: String
    public let source: String?
    public let sourceKind: String
    public let fetchSupported: Bool
    public let fetchSupportReason: String?
    public let matchScope: String
    public let queryAttempt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case snippet
        case technology
        case source
        case sourceKind = "source_kind"
        case fetchSupported = "fetch_supported"
        case fetchSupportReason = "fetch_support_reason"
        case matchScope = "match_scope"
        case queryAttempt = "query_attempt"
    }

    public init(
        id: String,
        title: String,
        snippet: String?,
        technology: String,
        source: String?,
        sourceKind: String,
        fetchSupported: Bool,
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

public struct CLITechnologyPayload: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let category: String?
}

public struct CLISearchDiagnosticPayload: Codable, Sendable, Equatable {
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
        reason: String?,
        hint: String?,
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

public struct CLIFetchDiagnosticPayload: Codable, Sendable, Equatable {
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

public struct CLICommandPayload: Codable, Sendable, Equatable {
    public let command: String
    public let caller: String?
    public let query: String?
    public let id: String?
    public let category: String?
    public let source: String?
    public let durationMs: Double
    public let resultCount: Int
    public let selectedPaths: [String]
    public let exitCategory: CLIExitCategory
    public let body: String?
    public let results: [CLISearchResultPayload]?
    public let technologies: [CLITechnologyPayload]?
    public let searchDiagnostics: [CLISearchDiagnosticPayload]?
    public let fetchDiagnostics: [CLIFetchDiagnosticPayload]?
    public let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case command
        case caller
        case query
        case id
        case category
        case source
        case durationMs = "duration_ms"
        case resultCount = "result_count"
        case selectedPaths = "selected_paths"
        case exitCategory = "exit_category"
        case body
        case results
        case technologies
        case searchDiagnostics = "search_diagnostics"
        case fetchDiagnostics = "fetch_diagnostics"
        case errorMessage = "error_message"
    }

    public init(
        command: String,
        caller: String?,
        query: String?,
        id: String?,
        category: String?,
        source: String?,
        durationMs: Double,
        resultCount: Int,
        selectedPaths: [String],
        exitCategory: CLIExitCategory,
        body: String?,
        results: [CLISearchResultPayload]?,
        technologies: [CLITechnologyPayload]?,
        searchDiagnostics: [CLISearchDiagnosticPayload]?,
        fetchDiagnostics: [CLIFetchDiagnosticPayload]? = nil,
        errorMessage: String?
    ) {
        self.command = command
        self.caller = caller
        self.query = query
        self.id = id
        self.category = category
        self.source = source
        self.durationMs = durationMs
        self.resultCount = resultCount
        self.selectedPaths = selectedPaths
        self.exitCategory = exitCategory
        self.body = body
        self.results = results
        self.technologies = technologies
        self.searchDiagnostics = searchDiagnostics
        self.fetchDiagnostics = fetchDiagnostics
        self.errorMessage = errorMessage
    }
}
