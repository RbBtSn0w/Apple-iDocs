import Foundation
import Logging
import MCP

public struct FetchDocTool {
    private let logger = Logger(label: "com.snow.idocs-fetch-tool")
    private let api = AppleJSONAPI()
    private let renderer = DocCRenderer()
    
    public init() {}
    
    public func run(path: String) async throws -> String {
        logger.info("Fetching Apple documentation for path: \(path)")
        
        let content = try await api.fetchDoc(path: path)
        return try renderer.render(content)
    }
}
