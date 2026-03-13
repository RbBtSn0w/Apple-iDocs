import Foundation
import Logging
import MCP

public struct SearchDocsTool {
    private let logger = Logger(label: "com.snow.idocs-search-tool")
    private let api = AppleJSONAPI()
    
    public init() {}
    
    public func run(query: String) async throws -> [SearchResult] {
        logger.info("Searching Apple documentation for: \(query)")
        
        // Phase 3 implementation only includes remote search for now
        // Phase 5 will add local Xcode and cache logic
        return try await api.search(query: query)
    }
}
