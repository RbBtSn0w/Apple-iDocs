import Foundation
import Logging

public struct FetchHIGTool {
    private let logger = Logger(label: "com.snow.idocs-fetch-hig")
    private let fetcher: HIGFetcher
    
    public init(fetcher: HIGFetcher = HIGFetcher()) {
        self.fetcher = fetcher
    }
    
    public func run(topic: String) async throws -> String {
        logger.info("Fetching HIG content for topic: \(topic)")
        
        return try await fetcher.fetch(topic: topic)
    }
}
