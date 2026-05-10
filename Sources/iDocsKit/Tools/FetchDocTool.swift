import Foundation
import Logging

public struct FetchDocTool {
    private let logger = Logger(label: "com.snow.idocs-fetch-tool")
    private let appleAPI: AppleJSONAPI
    private let sosumiAPI: SosumiAPI
    private let xcodeDocs: XcodeLocalDocs
    private let renderer = DocCRenderer()
    private let diskCache: DiskCache
    
    public init(api: AppleJSONAPI = AppleJSONAPI(),
                sosumiAPI: SosumiAPI = SosumiAPI(),
                xcodeDocs: XcodeLocalDocs = XcodeLocalDocs(),
                diskCache: DiskCache = DiskCache(name: "docs")) {
        self.appleAPI = api
        self.sosumiAPI = sosumiAPI
        self.xcodeDocs = xcodeDocs
        self.diskCache = diskCache
    }
    
    public func run(path: String) async throws -> String {
        try await runDetailed(path: path).markdown
    }

    public func runDetailed(path: String) async throws -> FetchDocResult {
        logger.info("Fetching Apple documentation for path: \(path)")
        
        // 1. Try Disk Cache
        if let cachedData = try? await diskCache.get(path) {
            if let content = try? JSONDecoder().decode(DocCContent.self, from: cachedData) {
                logger.info("Disk cache hit for: \(path)")
                return FetchDocResult(markdown: try renderer.render(content), source: .cache)
            }
            if let markdown = String(data: cachedData, encoding: .utf8), !markdown.isEmpty {
                logger.info("Disk cache markdown hit for: \(path)")
                return FetchDocResult(markdown: markdown, source: .cache)
            }
        }
        
        // 2. Try Local Xcode
        if let localContent = try? await xcodeDocs.fetchDoc(path: path) {
            logger.info("Local Xcode documentation hit for: \(path)")
            if let data = try? JSONEncoder().encode(localContent) {
                try? await diskCache.set(path, value: data, ttl: 3600 * 24)
            }
            return FetchDocResult(markdown: try renderer.render(localContent), source: .local)
        }
        
        // 3. Try Apple Remote API
        do {
            let content = try await appleAPI.fetchDoc(path: path)
            if let data = try? JSONEncoder().encode(content) {
                try? await diskCache.set(path, value: data, ttl: 3600 * 24)
            }
            return FetchDocResult(markdown: try renderer.render(content), source: .apple)
        } catch {
            logger.warning("Apple remote fetch failed: \(error.localizedDescription). Trying sosumi fallback.")
        }

        // 4. Try sosumi remote fallback (already rendered markdown)
        let markdown = try await sosumiAPI.fetchMarkdown(path: path)
        if let data = markdown.data(using: .utf8) {
            try? await diskCache.set(path, value: data, ttl: 3600 * 12)
        }
        return FetchDocResult(markdown: markdown, source: .sosumi)
    }
}

public struct FetchDocResult: Sendable {
    public let markdown: String
    public let source: DataSource

    public init(markdown: String, source: DataSource) {
        self.markdown = markdown
        self.source = source
    }
}
