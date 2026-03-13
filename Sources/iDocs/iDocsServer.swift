import Foundation
import MCP
import ServiceLifecycle
import Logging

public actor iDocsServer: Service {
    private let server: Server
    private let logger: Logger
    
    public init() {
        self.logger = Logger(label: "com.snow.idocs-server")
        self.server = Server(
            name: "iDocs",
            version: "1.0.0",
            capabilities: .init(
                logging: .init(),
                resources: .init(subscribe: true, listChanged: true),
                tools: .init(listChanged: true)
            )
        )
    }
    
    private func setupHandlers() async {
        // List available tools
        await server.withMethodHandler(ListTools.self) { _ in
            let tools = [
                Tool(
                    name: "search_docs",
                    description: "Search Apple documentation (Xcode local, disk cache, and remote API)",
                    inputSchema: .object([
                        "properties": .object([
                            "query": .string("Search query (keywords, supports * and ? wildcards)")
                        ]),
                        "required": .array([.string("query")])
                    ])
                )
            ]
            return .init(tools: tools)
        }
        
        // Handle tool calls
        await server.withMethodHandler(CallTool.self) { [self] params in
            switch params.name {
            case "search_docs":
                guard let query = params.arguments?["query"]?.stringValue else {
                    return .init(content: [.text("Missing query parameter")], isError: true)
                }
                
                do {
                    let results = try await SearchDocsTool().run(query: query)
                    let markdown = formatSearchResults(results)
                    return .init(content: [.text(markdown)], isError: false)
                } catch {
                    return .init(content: [.text("Search failed: \(error.localizedDescription)")], isError: true)
                }
                
            default:
                return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
            }
        }
    }
    
    private nonisolated func formatSearchResults(_ results: [SearchResult]) -> String {
        if results.isEmpty {
            return "No matching documentation found."
        }
        
        var output = "### Apple Documentation Search Results\n\n"
        for result in results {
            output += "#### \(result.title) (\(result.kind.rawValue))\n"
            if let abstract = result.abstract {
                output += "\(abstract)\n"
            }
            output += "- Path: `\(result.path)`\n"
            output += "- Source: \(result.source.rawValue)\n\n"
        }
        return output
    }
    
    public func run() async throws {
        logger.info("iDocs MCP Server starting...")
        
        // Register handlers before starting transport
        await setupHandlers()
        
        let transport = StdioTransport()
        try await server.start(transport: transport)
        
        // Keep the server running
        try await Task.sleep(for: .seconds(365 * 24 * 60 * 60))
    }
    
    public func shutdown() async {
        logger.info("iDocs MCP Server shutting down...")
        await server.stop()
    }
}

@main
struct Main {
    static func main() async {
        let server = iDocsServer()
        let serviceGroup = ServiceGroup(
            services: [server],
            gracefulShutdownSignals: [.sigterm, .sigint],
            logger: Logger(label: "com.snow.idocs-main")
        )
        
        do {
            try await serviceGroup.run()
        } catch {
            print("Server error: \(error)")
        }
    }
}
