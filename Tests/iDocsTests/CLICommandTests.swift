import Testing
import Foundation
import iDocsAdapter
@testable import iDocsApp

@Suite("CLI Command Tests", .serialized)
struct CLICommandTests {
    @Test("CLI version flag is recognized")
    func testCLIVersionFlag() throws {
        let command = try iDocsCLI.parse(["--version"])
        #expect(command.version == true)
        
        let commandShort = try iDocsCLI.parse(["-v"])
        #expect(commandShort.version == true)
    }

    @Test("CLI default behavior is help when no arguments")
    func testCLIDefaultBehavior() throws {
        let command = try iDocsCLI.parse([])
        #expect(command.version == false)
    }

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
        CLIEnvironment.configFactory = { DocumentationConfig(cachePath: "/tmp/idocs-tests") }
        CLIEnvironment.writeStdout = { capture.stdout.append($0) }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let code = await CLIExecutor.runSearch(query: "SwiftUI")

        #expect(code == 0)
        #expect(capture.stderr.isEmpty)
        #expect(capture.stdout.joined(separator: "\n").contains("View"))
        #expect(capture.stdout.joined(separator: "\n").contains("swiftui"))
        #expect(capture.stdout.joined(separator: "\n").contains("source: local"))
    }

    @Test("CLI search emits machine-readable JSON with caller context")
    func searchJSONOutputIncludesCaller() async throws {
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
                searchResults: [
                    SearchResult(
                        id: "/documentation/swiftui/view",
                        title: "View",
                        snippet: "UI",
                        technology: "swiftui",
                        source: .local
                    )
                ]
            )
        }
        CLIEnvironment.configFactory = { DocumentationConfig(cachePath: "/tmp/idocs-tests") }
        CLIEnvironment.writeStdout = { capture.stdout.append($0) }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let code = await CLIExecutor.runSearch(
            query: "SwiftUI",
            outputFormat: .json,
            callerID: "skill.swiftui-engineering"
        )

        #expect(code == 0)
        #expect(capture.stderr.isEmpty)
        let data = try #require(capture.stdout.first?.data(using: .utf8))
        let payload = try JSONDecoder().decode(CLICommandPayload.self, from: data)
        #expect(payload.command == "search")
        #expect(payload.caller == "skill.swiftui-engineering")
        #expect(payload.query == "SwiftUI")
        #expect(payload.exitCategory == .ok)
        #expect(payload.resultCount == 1)
        #expect(payload.selectedPaths == ["/documentation/swiftui/view"])
        #expect(payload.source == "local")
        #expect(payload.results?.first?.source == "local")
        #expect(payload.durationMs >= 0)
    }

    @Test("CLI search JSON exposes actionable diagnostics for empty results")
    func searchJSONOutputIncludesEmptyResultDiagnostics() async throws {
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
                searchResults: [],
                searchDiagnostics: SearchDiagnostics(
                    stages: [
                        SearchStageDiagnostic(
                            name: "apple",
                            status: "error",
                            durationMs: 1.0,
                            resultCount: 0,
                            reason: "remote_permission_denied",
                            hint: "Retry with network permission enabled."
                        ),
                        SearchStageDiagnostic(
                            name: "sosumi",
                            status: "miss",
                            durationMs: 1.0,
                            resultCount: 0,
                            reason: "remote_no_results",
                            hint: "Report this as a search-quality miss if the page exists on developer.apple.com."
                        )
                    ]
                )
            )
        }
        CLIEnvironment.configFactory = { DocumentationConfig(cachePath: "/tmp/idocs-tests") }
        CLIEnvironment.writeStdout = { capture.stdout.append($0) }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let code = await CLIExecutor.runSearch(
            query: "NavigationSplitView",
            outputFormat: .json,
            callerID: "skill.swiftui-engineering"
        )

        #expect(code == 0)
        #expect(capture.stderr.isEmpty)
        let data = try #require(capture.stdout.first?.data(using: .utf8))
        let payload = try JSONDecoder().decode(CLICommandPayload.self, from: data)

        #expect(payload.command == "search")
        #expect(payload.resultCount == 0)
        #expect(payload.searchDiagnostics?.map(\.name) == ["apple", "sosumi"])
        #expect(payload.searchDiagnostics?.first?.reason == "remote_permission_denied")
        #expect(payload.searchDiagnostics?.last?.reason == "remote_no_results")
        #expect(payload.searchDiagnostics?.last?.hint?.contains("search-quality miss") == true)
    }

    @Test("CLI search JSON distinguishes a true miss from network failure")
    func searchJSONOutputClassifiesTrueMiss() async throws {
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
                searchResults: [],
                searchDiagnostics: SearchDiagnostics(
                    stages: [
                        SearchStageDiagnostic(
                            name: "local",
                            status: "miss",
                            durationMs: 1.0,
                            resultCount: 0,
                            reason: "cache_miss",
                            hint: "Xcode DocumentationCache is unavailable."
                        ),
                        SearchStageDiagnostic(
                            name: "apple",
                            status: "miss",
                            durationMs: 1.0,
                            resultCount: 0,
                            reason: "remote_no_results",
                            hint: "Remote Apple lookup completed but returned no matching documentation."
                        ),
                        SearchStageDiagnostic(
                            name: "sosumi",
                            status: "miss",
                            durationMs: 1.0,
                            resultCount: 0,
                            reason: "remote_no_results",
                            hint: "Report this as a search-quality miss if the page exists on developer.apple.com."
                        )
                    ]
                )
            )
        }
        CLIEnvironment.configFactory = { DocumentationConfig(cachePath: "/tmp/idocs-tests") }
        CLIEnvironment.writeStdout = { capture.stdout.append($0) }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let code = await CLIExecutor.runSearch(
            query: "SomeFakeAPIThatDoesntExistInApple",
            outputFormat: .json,
            callerID: "skill.swiftui-engineering"
        )

        #expect(code == 0)
        #expect(capture.stderr.isEmpty)
        let data = try #require(capture.stdout.first?.data(using: .utf8))
        let payload = try JSONDecoder().decode(CLICommandPayload.self, from: data)

        #expect(payload.exitCategory == .ok)
        #expect(payload.errorMessage == nil)
        #expect(payload.resultCount == 0)
        #expect(payload.searchDiagnostics?.map(\.reason) == [
            "cache_miss",
            "remote_no_results",
            "remote_no_results"
        ])
        #expect(payload.searchDiagnostics?.contains { $0.reason == "remote_permission_denied" } == false)
        #expect(payload.searchDiagnostics?.contains { $0.reason == "remote_network_failure" } == false)
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

    @Test("CLI fetch emits machine-readable JSON body payload")
    func fetchJSONOutput() async throws {
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

        let code = await CLIExecutor.runFetch(
            id: "/documentation/swiftui/view",
            outputFormat: .json,
            callerID: "skill.swiftui-engineering"
        )

        #expect(code == 0)
        #expect(capture.stderr.isEmpty)
        let data = try #require(capture.stdout.first?.data(using: .utf8))
        let payload = try JSONDecoder().decode(CLICommandPayload.self, from: data)
        #expect(payload.command == "fetch")
        #expect(payload.id == "/documentation/swiftui/view")
        #expect(payload.source == "apple")
        #expect(payload.resultCount == 1)
        #expect(payload.selectedPaths == ["/documentation/swiftui/view"])
        #expect(payload.body == "# View")
    }

    @Test("CLI list prints technologies and supports category filtering")
    func listTechnologiesAndFilter() async {
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
                technologies: [
                    Technology(name: "SwiftUI", id: "/documentation/swiftui", category: "framework"),
                    Technology(name: "CloudKit", id: "/documentation/cloudkit", category: "service")
                ]
            )
        }
        CLIEnvironment.writeStdout = { capture.stdout.append($0) }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let code = await CLIExecutor.runList(category: "framework")

        #expect(code == 0)
        #expect(capture.stderr.isEmpty)
        let output = capture.stdout.joined(separator: "\n")
        #expect(output.contains("SwiftUI"))
        #expect(!output.contains("CloudKit"))
    }

    @Test("CLI list emits machine-readable JSON payload")
    func listJSONOutput() async throws {
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
                technologies: [
                    Technology(name: "SwiftUI", id: "/documentation/swiftui", category: "framework")
                ]
            )
        }
        CLIEnvironment.writeStdout = { capture.stdout.append($0) }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let code = await CLIExecutor.runList(
            category: "framework",
            outputFormat: .json,
            callerID: "skill.swiftui-engineering"
        )

        #expect(code == 0)
        #expect(capture.stderr.isEmpty)
        let data = try #require(capture.stdout.first?.data(using: .utf8))
        let payload = try JSONDecoder().decode(CLICommandPayload.self, from: data)
        #expect(payload.command == "list")
        #expect(payload.category == "framework")
        #expect(payload.source == "apple")
        #expect(payload.resultCount == 1)
        #expect(payload.technologies?.first?.name == "SwiftUI")
    }

    @Test("CLI JSON mode preserves structured errors on stdout")
    func jsonErrorOutput() async throws {
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
            MockDocumentationAdapter(errorToThrow: .networkError(message: "connection lost"))
        }
        CLIEnvironment.writeStdout = { capture.stdout.append($0) }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let code = await CLIExecutor.runSearch(
            query: "SwiftUI",
            outputFormat: .json,
            callerID: "skill.swiftui-engineering"
        )

        #expect(code == 1)
        #expect(capture.stderr.joined(separator: "\n").contains("Error [NETWORK]"))
        let data = try #require(capture.stdout.first?.data(using: .utf8))
        let payload = try JSONDecoder().decode(CLICommandPayload.self, from: data)
        #expect(payload.command == "search")
        #expect(payload.exitCategory == .network)
        #expect(payload.errorMessage?.contains("Error [NETWORK]") == true)
        #expect(payload.resultCount == 0)
    }

    @Test("CLI list returns standardized error mapping")
    func listStandardizedErrorOutput() async {
        let capture = OutputCapture()
        let previousServiceFactory = CLIEnvironment.serviceFactory
        let previousStderr = CLIEnvironment.writeStderr

        defer {
            CLIEnvironment.serviceFactory = previousServiceFactory
            CLIEnvironment.writeStderr = previousStderr
        }

        CLIEnvironment.serviceFactory = {
            MockDocumentationAdapter(errorToThrow: .networkError(message: "list failed"))
        }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let code = await CLIExecutor.runList(category: nil)

        #expect(code == 1)
        #expect(capture.stderr.joined(separator: "\n").contains("Error [NETWORK]"))
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
        #expect(content.contains("`idocs list"))
        #expect(content.contains("`--json`"))
        #expect(content.contains("`--caller <opaque-id>`"))
    }
}
