import Foundation
import Logging
import MCP

public struct SearchDocsTool {
    private let logger = Logger(label: "com.snow.idocs-search-tool")
    private let api = AppleJSONAPI()
    private let xcodeDocs = XcodeLocalDocs()
    
    public init() {}
    
    public func run(query: String) async throws -> [SearchResult] {
        logger.info("Searching Apple documentation for: \(query)")
        
        // 1. Try Local Xcode
        do {
            let localResults = try await xcodeDocs.search(query: query)
            if !localResults.isEmpty {
                logger.info("Found \(localResults.count) matches in local Xcode documentation.")
                return localResults
            }
        } catch {
            logger.warning("Local Xcode search failed: \(error.localizedDescription)")
        }
        
        // 2. Try Remote API (Fallback)
        logger.info("Falling back to remote API search.")
        return try await api.search(query: query)
    }
}
