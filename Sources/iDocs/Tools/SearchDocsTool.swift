import Foundation
import Logging
import MCP

public struct SearchDocsTool {
    private let logger = Logger(label: "com.snow.idocs-search-tool")
    private let api: AppleJSONAPI
    private let xcodeDocs: XcodeLocalDocs
    private let memoryCache: MemoryCache<String, [SearchResult]>
    
    public init(api: AppleJSONAPI = AppleJSONAPI(), 
                xcodeDocs: XcodeLocalDocs = XcodeLocalDocs(),
                memoryCache: MemoryCache<String, [SearchResult]> = MemoryCache<String, [SearchResult]>(capacity: 50)) {
        self.api = api
        self.xcodeDocs = xcodeDocs
        self.memoryCache = memoryCache
    }
    
    public func run(query: String) async throws -> [SearchResult] {
        logger.info("Searching Apple documentation for: \(query)")
        
        // 0. Try Memory Cache
        if let cached = await memoryCache.get(query) {
            logger.info("Memory cache hit for: \(query)")
            return cached
        }
        
        // 1. Try Local Xcode
        do {
            let localResults = try await xcodeDocs.search(query: query)
            if !localResults.isEmpty {
                logger.info("Found \(localResults.count) matches in local Xcode documentation.")
                await memoryCache.set(query, value: localResults)
                return localResults
            }
        } catch {
            logger.warning("Local Xcode search failed: \(error.localizedDescription)")
        }
        
        // 2. Try Remote API (Fallback)
        logger.info("Falling back to remote API search.")
        let results = try await api.search(query: query)
        await memoryCache.set(query, value: results)
        return results
    }
}
