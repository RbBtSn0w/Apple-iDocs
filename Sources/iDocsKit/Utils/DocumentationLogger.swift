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

#if canImport(Logging)
import Logging
#endif

private final class BootstrapState: @unchecked Sendable {
    private let lock = NSLock()
    private var isBootstrapped = false

    func bootstrapOnce(isVerbose: Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard !isBootstrapped else { return }
        isBootstrapped = true
        #if canImport(Logging)
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = isVerbose ? .debug : .warning
            return handler
        }
        #endif
    }
}

public enum DocumentationLoggingSystem {
    private static let state = BootstrapState()

    public static func bootstrap(isVerbose: Bool = false) {
        state.bootstrapOnce(isVerbose: isVerbose)
    }
}
