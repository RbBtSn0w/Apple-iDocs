import Foundation
import MCP
import ServiceLifecycle
import Logging

public enum TransportMode: String {
    case stdio
    case http
}

public actor iDocsServer: Service {
    private let server: Server
    private let logger: Logger
    private let mode: TransportMode
    private let port: Int
    
    public init(mode: TransportMode = .stdio, port: Int = 8080) {
        self.mode = mode
        self.port = port
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
                ),
                Tool(
                    name: "fetch_hig",
                    description: "Fetch content from Apple's Human Interface Guidelines (HIG)",
                    inputSchema: .object([
                        "properties": .object([
                            "topic": .string("HIG topic (e.g., navigation, icons, layouts)")
                        ]),
                        "required": .array([.string("topic")])
                    ])
                ),
                Tool(
                    name: "fetch_external_doc",
                    description: "Fetch DocC documentation from an external URL (e.g., swiftpackageindex.com)",
                    inputSchema: .object([
                        "properties": .object([
                            "url": .string("Complete URL to the external DocC documentation page")
                        ]),
                        "required": .array([.string("url")])
                    ])
                ),
                Tool(
                    name: "fetch_video_transcript",
                    description: "Fetch the text transcript for a WWDC video",
                    inputSchema: .object([
                        "properties": .object([
                            "videoID": .string("WWDC video identifier (e.g., wwdc2024-101)")
                        ]),
                        "required": .array([.string("videoID")])
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

            case "fetch_hig":
                guard let topic = params.arguments?["topic"]?.stringValue else {
                    return .init(content: [.text("Missing topic parameter")], isError: true)
                }
                
                do {
                    let markdown = try await FetchHIGTool().run(topic: topic)
                    return .init(content: [.text(markdown)], isError: false)
                } catch {
                    return .init(content: [.text("Fetch HIG failed: \(error.localizedDescription)")], isError: true)
                }

            case "fetch_external_doc":
                guard let url = params.arguments?["url"]?.stringValue else {
                    return .init(content: [.text("Missing url parameter")], isError: true)
                }
                
                do {
                    let markdown = try await FetchExternalDocTool().run(url: url)
                    return .init(content: [.text(markdown)], isError: false)
                } catch {
                    return .init(content: [.text("Fetch external doc failed: \(error.localizedDescription)")], isError: true)
                }

            case "fetch_video_transcript":
                guard let videoID = params.arguments?["videoID"]?.stringValue else {
                    return .init(content: [.text("Missing videoID parameter")], isError: true)
                }
                
                do {
                    let markdown = try await FetchVideoTranscriptTool().run(videoID: videoID)
                    return .init(content: [.text(markdown)], isError: false)
                } catch {
                    return .init(content: [.text("Fetch transcript failed: \(error.localizedDescription)")], isError: true)
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
        logger.info("iDocs MCP Server starting in \(mode.rawValue) mode...")
        
        // Register handlers before starting transport
        await setupHandlers()
        
        let transport: any Transport
        switch mode {
        case .stdio:
            transport = StdioTransport()
        case .http:
            // Note: StatefulHTTPServerTransport in the current SDK version might 
            // require a separate HTTP server (like Vapor/Hummingbird) to handle 
            // the networking layer. For now, we initialize the logic layer.
            transport = StatefulHTTPServerTransport()
        }
        
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
        let args = ProcessInfo.processInfo.arguments
        let mode: TransportMode = args.contains("--http") ? .http : .stdio
        let portIdx = args.firstIndex(of: "--port").map { args.index(after: $0) }
        let port = portIdx.flatMap { Int(args[$0]) } ?? 8080
        
        let server = iDocsServer(mode: mode, port: port)
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
