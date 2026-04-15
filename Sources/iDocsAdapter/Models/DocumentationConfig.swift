import Foundation

public struct DocumentationConfig: Sendable, Equatable {
    /// Active runtime knob used by the default adapter to place the disk cache.
    public let cachePath: String
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
        locale: Locale = Locale(identifier: "en_US_POSIX"),
        timeout: TimeInterval = 30,
        apiBaseURL: URL = URL(string: "https://developer.apple.com/tutorials/data")!,
        enableFileLocking: Bool = false
    ) {
        self.cachePath = cachePath
        self.locale = locale
        self.timeout = timeout
        self.apiBaseURL = apiBaseURL
        self.enableFileLocking = enableFileLocking
    }

    public static func cliDefault(fileManager: FileManager = .default) -> DocumentationConfig {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let path = caches.appendingPathComponent("iDocs").appendingPathComponent("docs").path
        return DocumentationConfig(cachePath: path)
    }
}
