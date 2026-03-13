import Foundation
import Logging
import MCP

public struct FetchDocTool {
    private let logger = Logger(label: "com.snow.idocs-fetch-tool")
    private let api: AppleJSONAPI
    private let xcodeDocs: XcodeLocalDocs
    private let renderer = DocCRenderer()
    private let diskCache: DiskCache
    
    public init(api: AppleJSONAPI = AppleJSONAPI(),
                xcodeDocs: XcodeLocalDocs = XcodeLocalDocs(),
                diskCache: DiskCache = DiskCache(name: "docs")) {
        self.api = api
        self.xcodeDocs = xcodeDocs
        self.diskCache = diskCache
    }
    
    public func run(path: String) async throws -> String {
        logger.info("Fetching Apple documentation for path: \(path)")
        
        // 1. Try Disk Cache
        if let cachedData = try? await diskCache.get(path),
           let content = try? JSONDecoder().decode(DocCContent.self, from: cachedData) {
            logger.info("Disk cache hit for: \(path)")
            return try renderer.render(content)
        }
        
        // 2. Try Local Xcode
        if let localContent = try? await xcodeDocs.fetchDoc(path: path) {
            logger.info("Local Xcode documentation hit for: \(path)")
            if let data = try? JSONEncoder().encode(localContent) {
                try? await diskCache.set(path, value: data, ttl: 3600 * 24)
            }
            return try renderer.render(localContent)
        }
        
        // 3. Try Remote API
        let content = try await api.fetchDoc(path: path)
        if let data = try? JSONEncoder().encode(content) {
            try? await diskCache.set(path, value: data, ttl: 3600 * 24)
        }
        return try renderer.render(content)
    }
}
