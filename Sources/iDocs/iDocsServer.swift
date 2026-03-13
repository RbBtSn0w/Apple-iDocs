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
        // Handlers will be registered here as tools are implemented
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
