import Foundation

public struct DocumentationConfig: Sendable, Equatable {
    /// Active runtime knob used by the default adapter to place the disk cache.
    public let cachePath: String
    /// Optional opaque caller identity supplied by the application layer.
    public let callerID: String?
    /// Optional local usage log path for CLI and agent-side observability.
    public let usageLogPath: String?
    /// Optional category filter for technology-list workflows.
    public let technologyCategoryFilter: String?
    /// Active locale metadata carried through adapter responses.
    public let locale: Locale
    /// Reserved for future transport-level customization. The current default CLI adapter does not override URLSession timeouts with this value.
    public let timeout: TimeInterval
    /// Reserved for future datasource overrides. The current default CLI adapter uses built-in endpoint resolution.
    public let apiBaseURL: URL
    /// Active flag controlling optional advisory file locking for shared-cache scenarios.
    public let enableFileLocking: Bool

    public init(
        cachePath: String,
        callerID: String? = nil,
        usageLogPath: String? = nil,
        technologyCategoryFilter: String? = nil,
        locale: Locale = Locale(identifier: "en_US_POSIX"),
        timeout: TimeInterval = 30,
        apiBaseURL: URL = URL(string: "https://developer.apple.com/tutorials/data")!,
        enableFileLocking: Bool = false
    ) {
        self.cachePath = cachePath
        self.callerID = callerID
        self.usageLogPath = usageLogPath
        self.technologyCategoryFilter = technologyCategoryFilter
        self.locale = locale
        self.timeout = timeout
        self.apiBaseURL = apiBaseURL
        self.enableFileLocking = enableFileLocking
    }

    public static func cliDefault(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DocumentationConfig {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let root = caches.appendingPathComponent("iDocs", isDirectory: true)
        let defaultCachePath = root.appendingPathComponent("docs", isDirectory: true).path
        let defaultUsageLogPath = root
            .appendingPathComponent("logs", isDirectory: true)
            .appendingPathComponent("usage.jsonl")
            .path
        let cachePath = nonEmptyEnvironmentValue("IDOCS_CACHE_PATH", environment: environment)
            ?? defaultCachePath
        let usageLogPath = nonEmptyEnvironmentValue("IDOCS_USAGE_LOG_PATH", environment: environment)
            ?? defaultUsageLogPath
        return DocumentationConfig(cachePath: cachePath, usageLogPath: usageLogPath)
    }

    public func withInvocationContext(
        callerID: String?
    ) -> DocumentationConfig {
        DocumentationConfig(
            cachePath: cachePath,
            callerID: callerID,
            usageLogPath: usageLogPath,
            technologyCategoryFilter: technologyCategoryFilter,
            locale: locale,
            timeout: timeout,
            apiBaseURL: apiBaseURL,
            enableFileLocking: enableFileLocking
        )
    }

    public func withInvocationContext(
        callerID: String?,
        technologyCategoryFilter: String?
    ) -> DocumentationConfig {
        DocumentationConfig(
            cachePath: cachePath,
            callerID: callerID,
            usageLogPath: usageLogPath,
            technologyCategoryFilter: technologyCategoryFilter,
            locale: locale,
            timeout: timeout,
            apiBaseURL: apiBaseURL,
            enableFileLocking: enableFileLocking
        )
    }

    private static func nonEmptyEnvironmentValue(
        _ key: String,
        environment: [String: String]
    ) -> String? {
        guard let rawValue = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return nil
        }
        return rawValue
    }
}
