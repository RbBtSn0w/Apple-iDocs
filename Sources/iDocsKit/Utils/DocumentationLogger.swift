import Foundation

public enum DocumentationLogLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
}

public protocol DocumentationLogger: Sendable {
    func log(level: DocumentationLogLevel, message: String, context: [String: String]?)
}

public struct NoopDocumentationLogger: DocumentationLogger {
    public init() {}

    public func log(level: DocumentationLogLevel, message: String, context: [String: String]?) {
        _ = (level, message, context)
    }
}
