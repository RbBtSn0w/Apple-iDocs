import Foundation
import iDocsApp
import iDocsTelemetry

@main
struct Main {
    @available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
    nonisolated static func main() async {
        let arguments = CommandLine.arguments
        let parsedArguments = Array(arguments.dropFirst())
        let version = CLIVersion.current()
        let environment = ProcessInfo.processInfo.environment

        await iDocsTelemetry.withRootSpan(
            arguments: arguments,
            serviceVersion: version,
            environment: environment
        ) {
            await iDocsCLI.main(parsedArguments)
        }
    }
}
