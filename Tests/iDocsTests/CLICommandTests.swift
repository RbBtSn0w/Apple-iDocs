import Testing
import Foundation
import iDocsAdapter
@testable import iDocsApp

@Suite("CLI Command Tests")
struct CLICommandTests {
    final class OutputCapture: @unchecked Sendable {
        var stdout: [String] = []
        var stderr: [String] = []
    }

    @Test("CLI search delegates through injected mock adapter only")
    func searchDelegatesToMockAdapter() async {
        let capture = OutputCapture()
        let previousServiceFactory = CLIEnvironment.serviceFactory
        let previousConfigFactory = CLIEnvironment.configFactory
        let previousStdout = CLIEnvironment.writeStdout
        let previousStderr = CLIEnvironment.writeStderr

        defer {
            CLIEnvironment.serviceFactory = previousServiceFactory
            CLIEnvironment.configFactory = previousConfigFactory
            CLIEnvironment.writeStdout = previousStdout
            CLIEnvironment.writeStderr = previousStderr
        }

        CLIEnvironment.serviceFactory = {
            MockDocumentationAdapter(
                searchResults: [SearchResult(id: "/documentation/swiftui/view", title: "View", snippet: "UI", technology: "swiftui", source: .local)]
            )
        }
        CLIEnvironment.configFactory = { DocumentationConfig(cachePath: "/tmp/idocs-cli-tests") }
        CLIEnvironment.writeStdout = { capture.stdout.append($0) }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let code = await CLIExecutor.runSearch(query: "SwiftUI")

        #expect(code == 0)
        #expect(capture.stderr.isEmpty)
        #expect(capture.stdout.joined(separator: "\n").contains("View"))
        #expect(capture.stdout.joined(separator: "\n").contains("swiftui"))
        #expect(capture.stdout.joined(separator: "\n").contains("source: local"))
    }

    @Test("CLI outputs standardized DocumentationError mapping")
    func standardizedErrorOutput() async {
        let capture = OutputCapture()
        let previousServiceFactory = CLIEnvironment.serviceFactory
        let previousStderr = CLIEnvironment.writeStderr

        defer {
            CLIEnvironment.serviceFactory = previousServiceFactory
            CLIEnvironment.writeStderr = previousStderr
        }

        CLIEnvironment.serviceFactory = {
            MockDocumentationAdapter(errorToThrow: .networkError(message: "connection lost"))
        }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let code = await CLIExecutor.runSearch(query: "SwiftUI")

        #expect(code == 1)
        #expect(capture.stderr.joined(separator: "\n").contains("Error [NETWORK]"))
    }

    @Test("CLI reports version mismatch clearly")
    func versionMismatchReporting() async {
        let capture = OutputCapture()
        let previousServiceFactory = CLIEnvironment.serviceFactory
        let previousStderr = CLIEnvironment.writeStderr

        defer {
            CLIEnvironment.serviceFactory = previousServiceFactory
            CLIEnvironment.writeStderr = previousStderr
        }

        CLIEnvironment.serviceFactory = {
            throw DocumentationError.incompatibleVersion(adapter: "2.0.0", core: "1.0.0")
        }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let code = await CLIExecutor.runSearch(query: "SwiftUI")

        #expect(code == 1)
        #expect(capture.stderr.joined(separator: "\n").contains("VERSION_MISMATCH"))
        #expect(capture.stderr.joined(separator: "\n").contains("2.0.0"))
        #expect(capture.stderr.joined(separator: "\n").contains("1.0.0"))
    }

    @Test("CLI fetch prints source marker when metadata contains source")
    func fetchSourceMarker() async {
        let capture = OutputCapture()
        let previousServiceFactory = CLIEnvironment.serviceFactory
        let previousStdout = CLIEnvironment.writeStdout
        let previousStderr = CLIEnvironment.writeStderr

        defer {
            CLIEnvironment.serviceFactory = previousServiceFactory
            CLIEnvironment.writeStdout = previousStdout
            CLIEnvironment.writeStderr = previousStderr
        }

        CLIEnvironment.serviceFactory = {
            MockDocumentationAdapter(
                documentByID: [
                    "/documentation/swiftui/view": DocumentationContent(
                        title: "View",
                        body: "# View",
                        metadata: ["source": "apple"],
                        url: URL(string: "https://developer.apple.com/documentation/swiftui/view")!
                    )
                ]
            )
        }
        CLIEnvironment.writeStdout = { capture.stdout.append($0) }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let code = await CLIExecutor.runFetch(id: "/documentation/swiftui/view")

        #expect(code == 0)
        #expect(capture.stderr.isEmpty)
        #expect(capture.stdout.joined(separator: "\n").contains("[source: apple]"))
    }

    @Test("CLI contract docs include search and fetch commands")
    func contractDocsContainCommands() throws {
        let fm = FileManager.default
        let env = ProcessInfo.processInfo.environment
        var sourceRoot = URL(fileURLWithPath: #filePath)
        sourceRoot.deleteLastPathComponent() // iDocsTests
        sourceRoot.deleteLastPathComponent() // Tests
        sourceRoot.deleteLastPathComponent() // repo root

        let candidateRoots: [URL] = [
            sourceRoot,
            URL(fileURLWithPath: env["SRCROOT"] ?? "", isDirectory: true),
            URL(fileURLWithPath: fm.currentDirectoryPath, isDirectory: true)
        ].filter { !$0.path.isEmpty }

        guard let contract = candidateRoots
            .map({ root in
                root.appendingPathComponent("specs")
                    .appendingPathComponent("006-cli-multisource-docs")
                    .appendingPathComponent("contracts")
                    .appendingPathComponent("cli-interface.md")
            })
            .first(where: { fm.isReadableFile(atPath: $0.path) }) else {
            // In sandboxed test runs, repo docs may be inaccessible.
            return
        }

        let content = try String(contentsOf: contract)

        #expect(content.contains("`idocs search <query>`"))
        #expect(content.contains("`idocs fetch <id>`"))
    }
}
