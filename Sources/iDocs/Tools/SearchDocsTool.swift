import Foundation
import Logging

public struct SearchDocsTool {
    private let logger = Logger(label: "com.snow.idocs-search-tool")
    private let appleAPI: AppleJSONAPI
    private let sosumiAPI: SosumiAPI
    private let xcodeDocs: XcodeLocalDocs
    private let memoryCache: MemoryCache<String, [SearchResult]>
    
    public init(api: AppleJSONAPI = AppleJSONAPI(),
                sosumiAPI: SosumiAPI = SosumiAPI(),
                xcodeDocs: XcodeLocalDocs = XcodeLocalDocs(),
                memoryCache: MemoryCache<String, [SearchResult]> = MemoryCache<String, [SearchResult]>(capacity: 50)) {
        self.appleAPI = api
        self.sosumiAPI = sosumiAPI
        self.xcodeDocs = xcodeDocs
        self.memoryCache = memoryCache
    }
    
    public func run(query: String) async throws -> [SearchResult] {
        logger.info("Searching Apple documentation for: \(query)")
        
        // 0. Try Memory Cache
        if let cached = await memoryCache.get(query) {
            logger.info("Memory cache hit for: \(query)")
            return cached.map { result in
                SearchResult(
                    title: result.title,
                    abstract: result.abstract,
                    path: result.path,
                    kind: result.kind,
                    source: .cache,
                    relevance: result.relevance
                )
            }
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
        
        // 2. Try Apple Remote API
        do {
            logger.info("Falling back to Apple remote API search.")
            let appleResults = try await appleAPI.search(query: query)
            if !appleResults.isEmpty {
                await memoryCache.set(query, value: appleResults)
                return appleResults
            }
            logger.info("Apple remote returned no results, trying sosumi fallback.")
        } catch {
            logger.warning("Apple remote search failed: \(error.localizedDescription). Trying sosumi fallback.")
        }

        // 3. Try sosumi fallback
        let sosumiResults = try await sosumiAPI.search(query: query)
        await memoryCache.set(query, value: sosumiResults)
        return sosumiResults
    }
}
