import Foundation
import ArgumentParser
import iDocsAdapter

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
public struct iDocsCLI: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "idocs",
        abstract: "iDocs CLI",
        subcommands: [SearchCommand.self, ResolveCommand.self, FetchCommand.self, ListCommand.self]
    )

    @Flag(name: .shortAndLong, help: "Show the version.")
    var version = false

    public init() {}

    public func run() async throws {
        if version {
            emitVersion()
        } else {
            throw CleanExit.helpRequest(self)
        }
    }

    func emitVersion(_ resolvedVersion: String = CLIVersion.current()) {
        CLIEnvironment.writeStdout(resolvedVersion)
    }
}

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
public struct SearchCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search documentation"
    )

    @Argument(help: "Search query")
    var query: String

    @Flag(name: .long, help: "Emit machine-readable JSON output")
    var json = false

    @Option(name: .long, help: "Opaque caller identity for agent or workflow integration")
    var caller: String?

    public init() {}

    public mutating func run() async throws {
        let code = await CLIExecutor.runSearch(
            query: query,
            outputFormat: json ? .json : .text,
            callerID: caller
        )
        if code != 0 {
            throw ExitCode(code)
        }
    }
}

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
public struct ResolveCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "resolve",
        abstract: "Resolve structured Apple documentation intent"
    )

    @Option(name: .long, help: "Apple framework name, for example SwiftUI")
    var framework: String?

    @Option(name: .long, help: "Top-level symbol name")
    var symbol: String?

    @Option(name: .long, help: "Containing type name")
    var type: String?

    @Option(name: .long, help: "Member name")
    var member: String?

    @Option(name: .long, help: "Member kind, for example property or method")
    var memberKind: String?

    @Option(name: .long, help: "Apple source family")
    var sourceFamily: String?

    @Flag(name: .long, help: "Emit machine-readable JSON output")
    var json = false

    @Option(name: .long, help: "Opaque caller identity for agent or workflow integration")
    var caller: String?

    public init() {}

    public mutating func run() async throws {
        let code = await CLIExecutor.runResolve(
            intent: ResolveIntent(
                framework: framework,
                symbol: symbol,
                type: type,
                member: member,
                memberKind: memberKind,
                sourceFamily: sourceFamily
            ),
            outputFormat: json ? .json : .text,
            callerID: caller
        )
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

    @Flag(name: .long, help: "Emit machine-readable JSON output")
    var json = false

    @Option(name: .long, help: "Opaque caller identity for agent or workflow integration")
    var caller: String?

    public init() {}

    public mutating func run() async throws {
        let code = await CLIExecutor.runFetch(
            id: id,
            outputFormat: json ? .json : .text,
            callerID: caller
        )
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

    @Flag(name: .long, help: "Emit machine-readable JSON output")
    var json = false

    @Option(name: .long, help: "Opaque caller identity for agent or workflow integration")
    var caller: String?

    public init() {}

    public mutating func run() async throws {
        let code = await CLIExecutor.runList(
            category: category,
            outputFormat: json ? .json : .text,
            callerID: caller
        )
        if code != 0 {
            throw ExitCode(code)
        }
    }
}
