import Foundation
import ArgumentParser

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
public struct iDocsCLI: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "iDocs",
        abstract: "iDocs CLI",
        subcommands: [SearchCommand.self, FetchCommand.self, ListCommand.self]
    )

    public init() {}
}

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
public struct SearchCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search documentation"
    )

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

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
public struct FetchCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "fetch",
        abstract: "Fetch documentation content"
    )

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

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
public struct ListCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List technologies"
    )

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
