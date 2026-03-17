import Foundation
import MCP
import ServiceLifecycle
import Logging
import iDocsAdapter
import iDocsKit

public enum TransportMode: String, Sendable {
    case stdio
    case http
}

public actor iDocsServer: Service {
    private let server: Server
    private let logger: Logger
    private let mode: TransportMode
    private let port: Int
    private let adapter: any DocumentationService
    private let config: DocumentationConfig
    
    public init(
        mode: TransportMode = .stdio,
        port: Int = 8080,
        adapter: (any DocumentationService)? = nil,
        config: DocumentationConfig = .cliDefault(),
        logger: Logger = Logger(label: "com.snow.idocs-server")
    ) {
        let resolvedAdapter = adapter ?? (try! DefaultDocumentationAdapter(
            logger: StderrDocumentationLogger(underlying: logger)
        ))

        self.mode = mode
        self.port = port
        self.logger = logger
        self.config = config
        self.adapter = resolvedAdapter
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
    
    func setupHandlers() async {
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
                ),
                Tool(
                    name: "search_documentation",
                    description: "Alias for search_docs",
                    inputSchema: .object([
                        "properties": .object([
                            "query": .string("Search query")
                        ]),
                        "required": .array([.string("query")])
                    ])
                ),
                Tool(
                    name: "get_documentation",
                    description: "Alias for fetch_doc",
                    inputSchema: .object([
                        "properties": .object([
                            "path": .string("Documentation path")
                        ]),
                        "required": .array([.string("path")])
                    ])
                ),
                Tool(
                    name: "list_technologies",
                    description: "Alias for browse_technologies",
                    inputSchema: .object([:])
                )
            ]
            return .init(tools: tools)
        }
        
        // Handle tool calls
        await server.withMethodHandler(CallTool.self) { [self] params in
            await handleToolCall(name: params.name, arguments: params.arguments)
        }
    }
    
    func handleToolCall(name: String, arguments: [String: Value]?) async -> CallTool.Result {
        switch name {
        case "search_docs", "search_documentation":
            guard let query = arguments?["query"]?.stringValue else {
                return .init(content: [.text("Missing query parameter")], isError: true)
            }
            return await runTool {
                let results = try await adapter.search(query: query, config: config)
                return formatSearchResults(results)
            }
            
        case "fetch_doc", "get_documentation":
            guard let path = arguments?["path"]?.stringValue else {
                return .init(content: [.text("Missing path parameter")], isError: true)
            }
            return await runTool {
                let content = try await adapter.fetch(id: path, config: config)
                return content.body
            }
            
        case "xcode_docs":
            let query = arguments?["query"]?.stringValue
            let list = arguments?["list"]?.boolValue ?? false
            return await runTool {
                return try await XcodeDocsTool().run(query: query, list: list)
            }

        case "browse_technologies", "list_technologies":
            return await runTool {
                let technologies = try await adapter.listTechnologies(config: config)
                return formatTechnologies(technologies)
            }

        case "fetch_hig":
            guard let topic = arguments?["topic"]?.stringValue else {
                return .init(content: [.text("Missing topic parameter")], isError: true)
            }
            return await runTool {
                return try await FetchHIGTool().run(topic: topic)
            }

        case "fetch_external_doc":
            guard let url = arguments?["url"]?.stringValue else {
                return .init(content: [.text("Missing url parameter")], isError: true)
            }
            return await runTool {
                return try await FetchExternalDocTool().run(url: url)
            }

        case "fetch_video_transcript":
            guard let videoID = arguments?["videoID"]?.stringValue else {
                return .init(content: [.text("Missing videoID parameter")], isError: true)
            }
            return await runTool {
                return try await FetchVideoTranscriptTool().run(videoID: videoID)
            }
            
        default:
            return .init(content: [.text("Unknown tool: \(name)")], isError: true)
        }
    }
    
    func runTool(_ block: () async throws -> String) async -> CallTool.Result {
        do {
            let result = try await block()
            return .init(content: [.text(result)], isError: false)
        } catch {
            return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
        }
    }
    
    nonisolated func formatSearchResults(_ results: [iDocsAdapter.SearchResult]) -> String {
        if results.isEmpty {
            return "No matching documentation found."
        }
        
        var output = "### Apple Documentation Search Results\n\n"
        for result in results {
            output += "#### \(result.title)\n"
            if let snippet = result.snippet {
                output += "\(snippet)\n"
            }
            output += "- ID: `\(result.id)`\n"
            output += "- Technology: \(result.technology)\n\n"
        }
        return output
    }

    nonisolated func formatTechnologies(_ technologies: [iDocsAdapter.Technology]) -> String {
        if technologies.isEmpty {
            return "No technologies found in the catalog."
        }

        var output = "### Apple Technologies Catalog\n\n"
        for tech in technologies {
            output += "- **\(tech.name)**"
            if let category = tech.category {
                output += " (\(category))"
            }
            output += "\n"
            output += "  - ID: `\(tech.id)`\n"
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
    
    public static func parseArgs(_ args: [String]) -> (mode: TransportMode, port: Int) {
        let mode: TransportMode = args.contains("--http") ? .http : .stdio
        let portIdx = args.firstIndex(of: "--port").map { args.index(after: $0) }
        let port = portIdx.flatMap { Int(args[$0]) } ?? 8080
        return (mode, port)
    }
}

public struct StderrDocumentationLogger: DocumentationLogger, @unchecked Sendable {
    let underlying: Logger

    public init(underlying: Logger) {
        self.underlying = underlying
    }

    public func log(level: DocumentationLogLevel, message: String, context: [String : String]?) {
        switch level {
        case .debug:
            underlying.debug("\(message) \(contextDescription(context))")
        case .info:
            underlying.info("\(message) \(contextDescription(context))")
        case .warning:
            underlying.warning("\(message) \(contextDescription(context))")
        case .error:
            underlying.error("\(message) \(contextDescription(context))")
        }
    }

    private func contextDescription(_ context: [String: String]?) -> String {
        guard let context, !context.isEmpty else { return "" }
        let parts = context.keys.sorted().compactMap { key -> String? in
            guard let value = context[key] else { return nil }
            return "\(key)=\(value)"
        }
        return "[\(parts.joined(separator: ", "))]"
    }
}
