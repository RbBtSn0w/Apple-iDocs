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
                ),
                Tool(
                    name: "fetch_doc",
                    description: "Fetch full documentation content as high-quality Markdown",
                    inputSchema: .object([
                        "properties": .object([
                            "path": .string("Documentation path (e.g., /documentation/swiftui/view)")
                        ]),
                        "required": .array([.string("path")])
                    ])
                ),
                Tool(
                    name: "xcode_docs",
                    description: "Query Xcode local documentation sets and symbols",
                    inputSchema: .object([
                        "properties": .object([
                            "query": .string("Symbol query for search mode"),
                            "list": .object([
                                "type": .string("boolean"),
                                "description": .string("List available local documentation sets")
                            ])
                        ])
                    ])
                ),
                Tool(
                    name: "browse_technologies",
                    description: "Browse the catalog of Apple frameworks and technologies",
                    inputSchema: .object([:])
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
                
            case "fetch_doc":
                guard let path = params.arguments?["path"]?.stringValue else {
                    return .init(content: [.text("Missing path parameter")], isError: true)
                }
                
                do {
                    let markdown = try await FetchDocTool().run(path: path)
                    return .init(content: [.text(markdown)], isError: false)
                } catch {
                    return .init(content: [.text("Fetch failed: \(error.localizedDescription)")], isError: true)
                }
                
            case "xcode_docs":
                let query = params.arguments?["query"]?.stringValue
                let list = params.arguments?["list"]?.boolValue ?? false
                
                do {
                    let markdown = try await XcodeDocsTool().run(query: query, list: list)
                    return .init(content: [.text(markdown)], isError: false)
                } catch {
                    return .init(content: [.text("Xcode docs query failed: \(error.localizedDescription)")], isError: true)
                }

            case "browse_technologies":
                do {
                    let markdown = try await BrowseTechnologiesTool().run()
                    return .init(content: [.text(markdown)], isError: false)
                } catch {
                    return .init(content: [.text("Browse failed: \(error.localizedDescription)")], isError: true)
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
