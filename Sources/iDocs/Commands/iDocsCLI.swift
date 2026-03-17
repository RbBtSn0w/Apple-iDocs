import Foundation
import ArgumentParser

public struct iDocsCLI: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "iDocs",
        abstract: "iDocs CLI",
        subcommands: [SearchCommand.self, FetchCommand.self, ListCommand.self, ServeCommand.self]
    )

    @Flag(name: .long, help: "Run MCP server in HTTP mode")
    var http: Bool = false

    @Option(name: .long, help: "HTTP port when serving")
    var port: Int = 8080

    public init() {}

    public mutating func run() async throws {
        let code = await CLIExecutor.runServe(mode: http ? .http : .stdio, port: port)
        if code != 0 {
            throw ExitCode(code)
        }
    }
}

public struct ServeCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(abstract: "Start MCP server")

    @Flag(name: .long, help: "Run MCP server in HTTP mode")
    var http: Bool = false

    @Option(name: .long, help: "HTTP port when serving")
    var port: Int = 8080

    public init() {}

    public mutating func run() async throws {
        let code = await CLIExecutor.runServe(mode: http ? .http : .stdio, port: port)
        if code != 0 {
            throw ExitCode(code)
        }
    }
}

public struct SearchCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(abstract: "Search documentation")

    @Argument(help: "Search query")
    var query: String

    public init() {}

    public mutating func run() async throws {
        let code = await CLIExecutor.runSearch(query: query)
        if code != 0 {
            throw ExitCode(code)
        }
    }
}

public struct FetchCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(abstract: "Fetch documentation content")

    @Argument(help: "Documentation identifier/path")
    var id: String

    public init() {}

    public mutating func run() async throws {
        let code = await CLIExecutor.runFetch(id: id)
        if code != 0 {
            throw ExitCode(code)
        }
    }
}

public struct ListCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(abstract: "List technologies")

    @Option(name: .long, help: "Filter by category")
    var category: String?

    public init() {}

    public mutating func run() async throws {
        let code = await CLIExecutor.runList(category: category)
        if code != 0 {
            throw ExitCode(code)
        }
    }
}
