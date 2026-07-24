import Foundation
import iDocsApp
import iDocsTelemetry

#if canImport(Darwin)
import Darwin
#endif

@main
struct Main {
    @available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
    static func main() async {
        let arguments = CommandLine.arguments
        let parsedArguments = Array(arguments.dropFirst())
        let version = CLIVersion.current()
        let environment = ProcessInfo.processInfo.environment

        await runCLI(
            arguments: arguments,
            parsedArguments: parsedArguments,
            version: version,
            environment: environment
        )
    }

    @available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
    private nonisolated static func runCLI(
        arguments: [String],
        parsedArguments: [String],
        version: String,
        environment: [String: String]
    ) async {
        let exitCode = await iDocsTelemetry.withRootSpan(
            arguments: arguments,
            serviceVersion: version,
            environment: environment
        ) {
            await iDocsCLI.execute(arguments: parsedArguments)
        }

        if exitCode != 0 {
            exit(exitCode)
        }
    }
}
