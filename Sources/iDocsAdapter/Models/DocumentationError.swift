import Foundation

public enum DocumentationError: Error, LocalizedError, Sendable, Equatable {
    case notFound(id: String)
    case networkError(message: String)
    case parsingError(reason: String)
    case unauthorized
    case invalidConfiguration(message: String)
    case incompatibleVersion(adapter: String, core: String)
    case internalError(message: String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "Documentation for '\(id)' could not be found."
        case .networkError(let message):
            return "Network error: \(message)"
        case .parsingError(let reason):
            return "Parsing error: \(reason)"
        case .unauthorized:
            return "Unauthorized access."
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .incompatibleVersion(let adapter, let core):
            return "Incompatible adapter/core versions. adapter=\(adapter), core=\(core)"
        case .internalError(let message):
            return "Internal error: \(message)"
        }
    }
}
