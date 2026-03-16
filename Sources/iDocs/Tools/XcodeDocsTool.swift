import Foundation
import Logging
import MCP

public struct XcodeDocsTool {
    private let logger = Logger(label: "com.snow.idocs-xcode-tool")
    private let dataSource: XcodeLocalDocs
    
    public init(dataSource: XcodeLocalDocs = XcodeLocalDocs()) {
        self.dataSource = dataSource
    }
    
    public func run(query: String? = nil, list: Bool = false) async throws -> String {
        if list {
            let sdks = try await dataSource.listAvailableSDKs()
            return formatSDKList(sdks)
        }
        
        guard let query = query else {
            return "Missing query parameter for search mode."
        }
        
        let results = try await dataSource.search(query: query)
        return formatSearchResults(results, query: query)
    }
    
    private func formatSDKList(_ sdks: [XcodeLocalDocInfo]) -> String {
        if sdks.isEmpty {
            return "No Xcode documentation sets found locally."
        }
        
        var output = "### Local Xcode Documentation Sets\n\n"
        for sdk in sdks {
            output += "- **\(sdk.sdkVersion)** (\(sdk.platform))\n"
            output += "  - Path: `\(sdk.cachePath.path)`\n"
            output += "  - Index: \(sdk.hasIndex ? "✅ Available" : "❌ Missing")\n"
        }
        return output
    }
    
    private func formatSearchResults(_ results: [SearchResult], query: String) -> String {
        if results.isEmpty {
            return "No local documentation found matching '\(query)'."
        }
        
        var output = "### Local Xcode Documentation Results for '\(query)'\n\n"
        for result in results {
            output += "#### \(result.title) (\(result.kind.rawValue))\n"
            if let abstract = result.abstract {
                output += "\(abstract)\n"
            }
            output += "- Path: `\(result.path)`\n\n"
        }
        return output
    }
}
