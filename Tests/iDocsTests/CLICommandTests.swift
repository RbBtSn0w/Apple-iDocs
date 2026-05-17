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

    @Test("CLI default parse leaves version flag disabled")
    func testCLIDefaultVersionFlag() throws {
        let command = try iDocsCLI.parse([])
        #expect(command.version == false)
    }

    @Test("CLI version output uses injected stdout")
    func cliVersionOutputUsesInjectedStdout() throws {
        let capture = OutputCapture()
        let previousStdout = CLIEnvironment.writeStdout

        defer {
            CLIEnvironment.writeStdout = previousStdout
        }

        CLIEnvironment.writeStdout = { capture.stdout.append($0) }
        let command = try iDocsCLI.parse(["--version"])
        command.emitVersion("9.8.7-test")

        #expect(capture.stdout == ["9.8.7-test"])
    }

    @Test("CLI version resolver prefers sidecar next to executable")
    func cliVersionResolverPrefersSidecar() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let binary = root.appendingPathComponent("idocs")
        let sidecar = root.appendingPathComponent("idocs.version")
        try Data().write(to: binary)
        try "9.8.7\n".write(to: sidecar, atomically: true, encoding: .utf8)

        let version = CLIVersion.current(
            executableURL: binary,
            currentDirectoryURL: root.appendingPathComponent("work", isDirectory: true),
            environment: [:]
        )

        #expect(version == "9.8.7")
    }

    @Test("CLI version resolver falls back to npm package manifest")
    func cliVersionResolverFallsBackToNPMManifest() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let npmDirectory = root.appendingPathComponent("npm", isDirectory: true)
        let nestedDirectory = root.appendingPathComponent("nested/work", isDirectory: true)
        try FileManager.default.createDirectory(at: npmDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        try """
        {
          "name": "@rbbtsn0w/idocs",
          "version": "2.3.4"
        }
        """.write(to: npmDirectory.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

        let version = CLIVersion.current(
            executableURL: root.appendingPathComponent("missing-idocs"),
            currentDirectoryURL: nestedDirectory,
            environment: [:]
        )

        #expect(version == "2.3.4")
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
        #expect(payload.results?.first?.sourceKind == "documentation")
        #expect(payload.results?.first?.fetchSupported == true)
        #expect(payload.results?.first?.queryAttempt == "SwiftUI")
        #expect(payload.durationMs >= 0)
    }

    @Test("CLI resolve command parses structured API intent")
    func resolveCommandParsesStructuredIntent() throws {
        let command = try ResolveCommand.parse([
            "--framework", "SwiftUI",
            "--symbol", "NavigationSplitView",
            "--json",
            "--caller", "skill.swiftui-engineering"
        ])

        #expect(command.framework == "SwiftUI")
        #expect(command.symbol == "NavigationSplitView")
        #expect(command.json)
        #expect(command.caller == "skill.swiftui-engineering")
    }

    @Test("CLI resolve emits machine-readable JSON with evidence and diagnostics")
    func resolveJSONOutputIncludesEvidenceAndDiagnostics() async throws {
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
                resolveResult: ResolveResult(
                    canonicalPath: "/documentation/swiftui/navigationsplitview",
                    confidence: .high,
                    verifiedByFetch: true,
                    evidence: ResolveEvidence(
                        sourceFamily: "documentation",
                        source: "apple",
                        path: "/documentation/swiftui/navigationsplitview",
                        title: "NavigationSplitView",
                        summary: "A view that presents columns."
                    ),
                    candidates: [
                        ResolveCandidate(
                            path: "/documentation/swiftui/navigationsplitview",
                            title: "NavigationSplitView",
                            source: .direct,
                            matchQuality: .exact,
                            verifiedByFetch: true,
                            confidence: .high
                        )
                    ],
                    resolveDiagnostics: [
                        ResolveDiagnostic(
                            stage: "direct_path",
                            status: "hit",
                            reason: "fetch_verified",
                            pathAttempt: "/documentation/swiftui/navigationsplitview"
                        )
                    ],
                    fetchDiagnostics: [
                        FetchAttemptDiagnostic(source: "apple", status: "hit")
                    ]
                )
            )
        }
        CLIEnvironment.configFactory = { DocumentationConfig(cachePath: "/tmp/idocs-tests") }
        CLIEnvironment.writeStdout = { capture.stdout.append($0) }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let code = await CLIExecutor.runResolve(
            intent: ResolveIntent(framework: "SwiftUI", symbol: "NavigationSplitView"),
            outputFormat: .json,
            callerID: "skill.swiftui-engineering"
        )

        #expect(code == 0)
        #expect(capture.stderr.isEmpty)
        let data = try #require(capture.stdout.first?.data(using: .utf8))
        let payload = try JSONDecoder().decode(CLICommandPayload.self, from: data)
        #expect(payload.command == "resolve")
        #expect(payload.caller == "skill.swiftui-engineering")
        #expect(payload.canonicalPath == "/documentation/swiftui/navigationsplitview")
        #expect(payload.confidence == "high")
        #expect(payload.verifiedByFetch == true)
        #expect(payload.evidence?.source == "apple")
        #expect(payload.candidates?.first?.source == "direct")
        #expect(payload.resolveDiagnostics?.first?.stage == "direct_path")
        #expect(payload.fetchDiagnostics?.first?.source == "apple")
    }

    @Test("CLI resolve JSON preserves invalid intent errors without search fallback")
    func resolveInvalidIntentJSONOutput() async throws {
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
            MockDocumentationAdapter(errorToThrow: .invalidResolveIntent(message: "member requires type"))
        }
        CLIEnvironment.writeStdout = { capture.stdout.append($0) }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let code = await CLIExecutor.runResolve(
            intent: ResolveIntent(framework: "SwiftUI", member: "body"),
            outputFormat: .json,
            callerID: "skill.swiftui-engineering"
        )

        #expect(code == 1)
        #expect(capture.stderr.joined(separator: "\n").contains("Invalid resolve intent"))
        let data = try #require(capture.stdout.first?.data(using: .utf8))
        let payload = try JSONDecoder().decode(CLICommandPayload.self, from: data)
        #expect(payload.command == "resolve")
        #expect(payload.confidence == "unresolved")
        #expect(payload.verifiedByFetch == false)
        #expect(payload.results == nil)
        #expect(payload.resolveDiagnostics?.first?.reason == "invalid_intent")
    }

    @Test("CLI search JSON and text expose source kind and fetch support")
    func searchOutputIncludesSourceKindAndFetchSupport() async throws {
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
                        id: "/help/app-store-connect/manage-builds/upload-builds",
                        title: "Upload builds",
                        snippet: "Upload builds to App Store Connect.",
                        technology: "app-store-connect",
                        source: .sosumi,
                        sourceKind: "help",
                        fetchSupported: true,
                        matchScope: "path",
                        queryAttempt: "Xcode Cloud TestFlight App Store Connect"
                    ),
                    SearchResult(
                        id: "/news",
                        title: "Developer News",
                        snippet: "Apple developer news.",
                        technology: "unknown",
                        source: .sosumi,
                        sourceKind: "news",
                        fetchSupported: false,
                        fetchSupportReason: "unsupported_source_type",
                        matchScope: "path",
                        queryAttempt: "Xcode Cloud TestFlight App Store Connect"
                    )
                ]
            )
        }
        CLIEnvironment.configFactory = { DocumentationConfig(cachePath: "/tmp/idocs-tests") }
        CLIEnvironment.writeStdout = { capture.stdout.append($0) }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let textCode = await CLIExecutor.runSearch(query: "Xcode Cloud TestFlight App Store Connect")
        #expect(textCode == 0)
        let text = capture.stdout.joined(separator: "\n")
        #expect(text.contains("kind: help"))
        #expect(text.contains("fetch: supported"))
        #expect(text.contains("scope: path"))
        #expect(text.contains("kind: news"))
        #expect(text.contains("fetch: unsupported"))

        capture.stdout.removeAll()
        let jsonCode = await CLIExecutor.runSearch(
            query: "Xcode Cloud TestFlight App Store Connect",
            outputFormat: .json
        )
        #expect(jsonCode == 0)
        let data = try #require(capture.stdout.first?.data(using: .utf8))
        let payload = try JSONDecoder().decode(CLICommandPayload.self, from: data)
        #expect(payload.results?.first?.sourceKind == "help")
        #expect(payload.results?.first?.fetchSupported == true)
        #expect(payload.results?.first?.matchScope == "path")
        #expect(payload.results?.last?.fetchSupportReason == "unsupported_source_type")
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

    @Test("CLI search JSON includes local docs unavailable diagnostic from cache override")
    func searchJSONIncludesLocalDocsUnavailableDiagnosticFromCacheOverride() async throws {
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
            ConfigAwareSearchAdapter()
        }
        CLIEnvironment.configFactory = {
            DocumentationConfig.cliDefault(
                environment: [
                    "IDOCS_XCODE_DOC_CACHE_PATH": "/tmp/idocs-remote-only-doc-cache"
                ]
            )
        }
        CLIEnvironment.writeStdout = { capture.stdout.append($0) }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let code = await CLIExecutor.runSearch(
            query: "SwiftUI NavigationSplitView",
            outputFormat: .json
        )

        #expect(code == 0)
        #expect(capture.stderr.isEmpty)
        let data = try #require(capture.stdout.first?.data(using: .utf8))
        let payload = try JSONDecoder().decode(CLICommandPayload.self, from: data)
        let localStage = try #require(payload.searchDiagnostics?.first { $0.name == "local" })
        #expect(localStage.reason == "local_docs_unavailable")
        #expect(localStage.hint?.contains("remote-only") == true)
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

    @Test("CLI fetch JSON emits diagnostics for successful fallback")
    func fetchJSONOutputIncludesDiagnostics() async throws {
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
                    "/documentation/xcode/environment-variable-reference": DocumentationContent(
                        title: "Environment variable reference",
                        body: "# Environment variable reference",
                        metadata: ["source": "sosumi"],
                        url: URL(string: "https://developer.apple.com/documentation/xcode/environment-variable-reference")!,
                        fetchDiagnostics: [
                            FetchAttemptDiagnostic(source: "apple", status: "error", reason: "remote_decode_failed"),
                            FetchAttemptDiagnostic(source: "sosumi", status: "hit")
                        ]
                    )
                ]
            )
        }
        CLIEnvironment.writeStdout = { capture.stdout.append($0) }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let code = await CLIExecutor.runFetch(
            id: "/documentation/xcode/environment-variable-reference",
            outputFormat: .json
        )

        #expect(code == 0)
        let data = try #require(capture.stdout.first?.data(using: .utf8))
        let payload = try JSONDecoder().decode(CLICommandPayload.self, from: data)
        #expect(payload.fetchDiagnostics?.map(\.source) == ["apple", "sosumi"])
        #expect(payload.fetchDiagnostics?.first?.reason == "remote_decode_failed")
    }

    @Test("CLI fetch JSON classifies unsupported source type without NOT_FOUND")
    func fetchJSONUnsupportedSourceType() async throws {
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
                errorToThrow: .unsupportedSourceType(
                    id: "/videos/play/wwdc2024/10123",
                    sourceKind: "video",
                    attempts: [
                        FetchAttemptDiagnostic(source: "unsupported", status: "unsupported", reason: "unsupported_source_type")
                    ]
                )
            )
        }
        CLIEnvironment.writeStdout = { capture.stdout.append($0) }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let code = await CLIExecutor.runFetch(
            id: "/videos/play/wwdc2024/10123",
            outputFormat: .json
        )

        #expect(code == 1)
        let data = try #require(capture.stdout.first?.data(using: .utf8))
        let payload = try JSONDecoder().decode(CLICommandPayload.self, from: data)
        #expect(payload.exitCategory == .config)
        #expect(payload.exitCategory != .notFound)
        #expect(payload.fetchDiagnostics?.first?.reason == "unsupported_source_type")
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

private struct ConfigAwareSearchAdapter: DocumentationService {
    func search(query: String, config: DocumentationConfig) async throws -> [SearchResult] {
        try await searchDetailed(query: query, config: config).results
    }

    func searchDetailed(query: String, config: DocumentationConfig) async throws -> DocumentationSearchResponse {
        #expect(config.xcodeDocumentationCachePath == "/tmp/idocs-remote-only-doc-cache")
        return DocumentationSearchResponse(
            results: [],
            diagnostics: SearchDiagnostics(
                stages: [
                    SearchStageDiagnostic(
                        name: "local",
                        status: "miss",
                        durationMs: 1.0,
                        resultCount: 0,
                        reason: "local_docs_unavailable",
                        hint: "Xcode local documentation is unavailable; this run is remote-only until the local DocumentationCache is restored."
                    ),
                    SearchStageDiagnostic(
                        name: "apple",
                        status: "miss",
                        durationMs: 1.0,
                        resultCount: 0,
                        reason: "remote_no_results"
                    )
                ]
            )
        )
    }

    func resolve(intent: ResolveIntent, config: DocumentationConfig) async throws -> ResolveResult {
        throw DocumentationError.invalidResolveIntent(message: "not configured")
    }

    func fetch(id: String, config: DocumentationConfig) async throws -> DocumentationContent {
        throw DocumentationError.notFound(id: id)
    }

    func listTechnologies(config: DocumentationConfig) async throws -> [Technology] {
        []
    }

    func getCoreVersion() -> String {
        "1.0.0"
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("idocs-cli-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
