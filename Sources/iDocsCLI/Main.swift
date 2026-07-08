import Foundation
import iDocsApp
import iDocsTelemetry

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
        await iDocsTelemetry.withRootSpan(
            arguments: arguments,
            serviceVersion: version,
            environment: environment
        ) {
            await iDocsCLI.main(parsedArguments)
        }
    }
}
