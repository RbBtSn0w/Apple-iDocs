import Foundation
import Logging
import MCP

public struct FetchExternalDocTool {
    private let logger = Logger(label: "com.snow.idocs-fetch-external")
    private let fetcher: ExternalDocCFetcher
    private let renderer: DocCRenderer
    
    public init(fetcher: ExternalDocCFetcher = ExternalDocCFetcher(),
                renderer: DocCRenderer = DocCRenderer()) {
        self.fetcher = fetcher
        self.renderer = renderer
    }
    
    public func run(url: String) async throws -> String {
        guard let validURL = URL(string: url) else {
            return "Invalid URL: \(url)"
        }
        
        logger.info("Fetching external DocC documentation: \(url)")
        
        let content = try await fetcher.fetch(url: validURL)
        return try renderer.render(content)
    }
}
