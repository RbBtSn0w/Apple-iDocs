import Foundation

public struct DocumentationConfig: Sendable, Equatable {
    public let cachePath: String
    public let locale: Locale
    public let timeout: TimeInterval
    public let apiBaseURL: URL
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
