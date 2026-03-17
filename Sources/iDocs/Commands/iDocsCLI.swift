import Foundation
import ArgumentParser

private final class WaitBox: @unchecked Sendable {
    var code: Int32 = 1
    let semaphore = DispatchSemaphore(value: 0)
}

@inline(__always)
private func blockingWait(_ operation: @escaping @Sendable () async -> Int32) -> Int32 {
    let box = WaitBox()
    Task {
        box.code = await operation()
        box.semaphore.signal()
    }
    box.semaphore.wait()
    return box.code
}

public struct iDocsCLI: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "iDocs",
        abstract: "iDocs CLI",
        subcommands: [SearchCommand.self, FetchCommand.self, ListCommand.self, ServeCommand.self]
    )

    public init() {}
}

public struct ServeCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "serve",
        abstract: "Start MCP server"
    )

    @Flag(name: .long, help: "Run MCP server in HTTP mode")
    var http: Bool = false

    @Option(name: .long, help: "HTTP port when serving")
    var port: Int = 8080

    public init() {}

    public mutating func run() throws {
        let useHTTP = http
        let chosenPort = port
        let code = blockingWait {
            await CLIExecutor.runServe(mode: useHTTP ? .http : .stdio, port: chosenPort)
        }
        if code != 0 {
            throw ExitCode(code)
        }
    }
}

public struct SearchCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search documentation"
    )

    @Argument(help: "Search query")
    var query: String

    public init() {}

    public mutating func run() throws {
        let term = query
        let code = blockingWait {
            await CLIExecutor.runSearch(query: term)
        }
        if code != 0 {
            throw ExitCode(code)
        }
    }
}

public struct FetchCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "fetch",
        abstract: "Fetch documentation content"
    )

    @Argument(help: "Documentation identifier/path")
    var id: String

    public init() {}

    public mutating func run() throws {
        let identifier = id
        let code = blockingWait {
            await CLIExecutor.runFetch(id: identifier)
        }
        if code != 0 {
            throw ExitCode(code)
        }
    }
}

public struct ListCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List technologies"
    )

    @Option(name: .long, help: "Filter by category")
    var category: String?

    public init() {}

    public mutating func run() throws {
        let filter = category
        let code = blockingWait {
            await CLIExecutor.runList(category: filter)
        }
        if code != 0 {
            throw ExitCode(code)
        }
    }
}
