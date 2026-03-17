import Foundation
import Logging
import ServiceLifecycle
import iDocsAdapter
import iDocsMCPApp

@main
struct MCPMain {
    static func main() async {
        let logger = Logger(label: "com.snow.idocs-mcp-main")
        let args = Array(CommandLine.arguments.dropFirst())
        let mode: TransportMode = args.contains("--http") ? .http : .stdio
        let port = parsedPort(from: args) ?? 8080

        do {
            let adapter = try DefaultDocumentationAdapter(
                logger: StderrDocumentationLogger(underlying: logger)
            )
            let server = iDocsServer(
                mode: mode,
                port: port,
                adapter: adapter,
                config: DocumentationConfig.cliDefault(),
                logger: logger
            )
            let group = ServiceGroup(
                services: [server],
                gracefulShutdownSignals: [.sigterm, .sigint],
                logger: logger
            )
            try await group.run()
        } catch {
            FileHandle.standardError.write(Data("Error [INTERNAL]: \(error.localizedDescription)\n".utf8))
            Foundation.exit(1)
        }
    }

    private static func parsedPort(from args: [String]) -> Int? {
        guard let idx = args.firstIndex(of: "--port"), args.indices.contains(idx + 1) else {
            return nil
        }
        return Int(args[idx + 1])
    }
}
