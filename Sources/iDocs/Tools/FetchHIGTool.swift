import Foundation
import Logging
import MCP

public struct FetchHIGTool {
    private let logger = Logger(label: "com.snow.idocs-fetch-hig")
    private let fetcher = HIGFetcher()
    
    public init() {}
    
    public func run(topic: String) async throws -> String {
        logger.info("Fetching HIG content for topic: \(topic)")
        
        return try await fetcher.fetch(topic: topic)
    }
}
