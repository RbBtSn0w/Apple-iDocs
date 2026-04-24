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
}

public struct CLITechnologyPayload: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let category: String?
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
        case errorMessage = "error_message"
    }
}
