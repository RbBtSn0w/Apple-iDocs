import Foundation
import InMemoryExporter
import OpenTelemetryApi
import OpenTelemetrySdk
import Testing
@testable import iDocsApp
@testable import iDocsKit
import iDocsAdapter
@testable import iDocsTelemetry

@Suite("Telemetry Tests", .serialized)
struct TelemetryTests {
    @Test("OTLP traces endpoint resolution honors signal-specific, base, and default precedence")
    func endpointResolutionPrecedence() {
        let explicit = iDocsTelemetry.resolveTracesEndpoint(
            environment: [
                "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT": "https://explicit.example/v1/traces",
                "OTEL_EXPORTER_OTLP_ENDPOINT": "https://base.example"
            ]
        )
        #expect(explicit.absoluteString == "https://explicit.example/v1/traces")

        let base = iDocsTelemetry.resolveTracesEndpoint(
            environment: [
                "OTEL_EXPORTER_OTLP_ENDPOINT": "https://base.example/custom-root"
            ]
        )
        #expect(base.absoluteString == "https://base.example/custom-root/v1/traces")

        let baseWithSuffix = iDocsTelemetry.resolveTracesEndpoint(
            environment: [
                "OTEL_EXPORTER_OTLP_ENDPOINT": "https://base.example/v1/traces"
            ]
        )
        #expect(baseWithSuffix.absoluteString == "https://base.example/v1/traces")

        let fallback = iDocsTelemetry.resolveTracesEndpoint(environment: [:])
        #expect(fallback == iDocsTelemetry.defaultTracesEndpoint)
    }

    @Test("OTLP logs endpoint resolution honors signal-specific, base, and default precedence")
    func logsEndpointResolutionPrecedence() {
        let explicit = iDocsTelemetry.resolveLogsEndpoint(
            environment: [
                "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT": "https://explicit.example/v1/logs",
                "OTEL_EXPORTER_OTLP_ENDPOINT": "https://base.example"
            ]
        )
        #expect(explicit.absoluteString == "https://explicit.example/v1/logs")

        let base = iDocsTelemetry.resolveLogsEndpoint(
            environment: ["OTEL_EXPORTER_OTLP_ENDPOINT": "https://base.example/custom-root"]
        )
        #expect(base.absoluteString == "https://base.example/custom-root/v1/logs")

        let fallback = iDocsTelemetry.resolveLogsEndpoint(environment: [:])
        #expect(fallback == iDocsTelemetry.defaultLogsEndpoint)
    }

    @Test("OTLP HTTP transport preserves non-2xx responses for exporter handling")
    func otlpHTTPTransportPreservesNonSuccessResponse() throws {
        let responseBox = HTTPResponseBox()
        let response = try #require(
            HTTPURLResponse(
                url: URL(string: "https://otel.example.com/v1/logs")!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": "1"]
            )
        )

        responseBox.store(response: response, error: nil)

        switch responseBox.result() {
        case .success(let preservedResponse):
            #expect(preservedResponse.statusCode == 429)
            #expect(preservedResponse.value(forHTTPHeaderField: "Retry-After") == "1")
        case .failure(let error):
            Issue.record("Expected the HTTP response to reach the exporter, got \(error)")
        }
    }

    @Test("Telemetry opt-out detects both disable environment variables")
    func telemetryOptOut() {
        #expect(iDocsTelemetry.telemetryDisabled(environment: ["DISABLE_TELEMETRY": "1"]))
        #expect(iDocsTelemetry.telemetryDisabled(environment: ["DO_NOT_TRACK": "1"]))
        #expect(!iDocsTelemetry.telemetryDisabled(environment: [:]))
    }

    @Test("Traceparent extraction reads W3C parent context")
    func traceparentExtraction() {
        let context = iDocsTelemetry.extractParentSpanContext(
            environment: [
                "TRACEPARENT": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
            ]
        )

        #expect(context?.traceId.hexString == "4bf92f3577b34da6a3ce929d0e0e4736")
        #expect(context?.spanId.hexString == "00f067aa0ba902b7")
        #expect(context?.traceFlags.sampled == true)

        let contextFallback = iDocsTelemetry.extractParentSpanContext(
            environment: [
                "TRACEPARENT": "",
                "traceparent": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
            ]
        )
        #expect(contextFallback?.traceId.hexString == "4bf92f3577b34da6a3ce929d0e0e4736")
        #expect(contextFallback?.spanId.hexString == "00f067aa0ba902b7")
    }

    @Test("Root and child spans preserve parentage and record events")
    func rootAndChildSpanParentage() async throws {
        let exporter = InMemoryExporter()
        iDocsTelemetry.installForTesting(spanExporter: exporter)
        defer { iDocsTelemetry.shutdown() }

        await iDocsTelemetry.withRootSpan(
            arguments: ["/tmp/idocs", "search", "SwiftUI"],
            serviceVersion: "1.2.3",
            environment: [:]
        ) {
            await iDocsTelemetry.withSpan(
                "idocs.command.search",
                attributes: [
                    "idocs.command.name": .string("search")
                ]
            ) {
                #expect(iDocsTelemetry.currentSpanName() == "idocs.command.search")
                iDocsTelemetry.addEvent(
                    "idocs.stage",
                    attributes: [
                        "idocs.stage.name": .string("cache"),
                        "idocs.stage.status": .string("miss")
                    ]
                )
            }
        }
        iDocsTelemetry.flush()

        let spans = exporter.getFinishedSpanItems()
        #expect(spans.count == 2)

        let root = try #require(spans.first { $0.name == "idocs" })
        let child = try #require(spans.first { $0.name == "idocs.command.search" })

        #expect(child.parentSpanId == root.spanId)
        #expect(root.parentSpanId == nil)
        #expect(root.attributes["process.command"] == .string("idocs"))
        #expect(root.attributes["process.executable.name"] == .string("idocs"))
        #expect(root.attributes["process.command_args"] == .array(AttributeArray(values: [
            .string("idocs"),
            .string("search"),
            .string("<argument>")
        ])))
        #expect(child.attributes["idocs.command.name"] == .string("search"))
        #expect(child.events.map(\.name) == ["idocs.stage"])
    }

    @Test("Telemetry sanitizes sensitive paths and tokens in process.command_args")
    func telemetrySanitizesArguments() async throws {
        let exporter = InMemoryExporter()
        iDocsTelemetry.installForTesting(spanExporter: exporter)
        defer { iDocsTelemetry.shutdown() }

        await iDocsTelemetry.withRootSpan(
            arguments: ["/usr/local/bin/idocs", "--cache-path", "/Users/snow/library", "--token", "abcdef1234567890abcdef1234567890"],
            serviceVersion: "1.0.0",
            environment: [:]
        ) {
            // no-op
        }
        iDocsTelemetry.flush()

        let spans = exporter.getFinishedSpanItems()
        let root = try #require(spans.first { $0.name == "idocs" })
        #expect(root.attributes["process.command_args"] == .array(AttributeArray(values: [
            .string("idocs"),
            .string("--cache-path"),
            .string("<path>"),
            .string("--token"),
            .string("<redacted>")
        ])))
    }

    @Test("Telemetry redacts an unknown command positional argument")
    func telemetryRedactsUnknownCommand() async throws {
        let exporter = InMemoryExporter()
        iDocsTelemetry.installForTesting(spanExporter: exporter)
        defer { iDocsTelemetry.shutdown() }

        await iDocsTelemetry.withRootSpan(
            arguments: ["idocs", "/Users/snow/private-command", "secret-value"],
            serviceVersion: "1.0.0",
            environment: [:]
        ) {
            // no-op
        }
        iDocsTelemetry.flush()

        let root = try #require(
            exporter.getFinishedSpanItems().first { $0.name == "idocs" }
        )
        #expect(root.attributes["process.command_args"] == .array(AttributeArray(values: [
            .string("idocs"),
            .string("<argument>"),
            .string("<argument>")
        ])))
    }

    @Test("Final exceptions emit one privacy-safe trace-correlated log")
    func finalExceptionLogIsSafeAndCorrelated() async throws {
        let spanExporter = InMemoryExporter()
        let logExporter = TestLogRecordExporter()
        iDocsTelemetry.installForTesting(
            spanExporter: spanExporter,
            logRecordExporter: logExporter
        )
        defer { iDocsTelemetry.shutdown() }

        await iDocsTelemetry.withRootSpan(
            arguments: ["idocs", "fetch", "/Users/snow/private-doc"],
            serviceVersion: "1.0.0",
            environment: [:]
        ) {
            let descriptor = TelemetryFailureDescriptor(
                errorType: "not_found",
                category: "dependency",
                slug: "idocs.command.fetch.failed",
                expected: false,
                exceptionType: "iDocsError",
                safeMessage: "Documentation fetch failed."
            )
            iDocsTelemetry.captureException(descriptor)
        }
        iDocsTelemetry.flush()

        let root = try #require(spanExporter.getFinishedSpanItems().first { $0.name == "idocs" })
        let logs = logExporter.getFinishedLogRecords()
        #expect(logs.count == 1)
        let log = try #require(logs.first)

        #expect(log.eventName == "exception")
        #expect(log.severity == .error)
        #expect(log.body == .string("Documentation fetch failed."))
        #expect(log.attributes["exception.type"] == .string("iDocsError"))
        #expect(log.attributes["exception.message"] == .string("Documentation fetch failed."))
        #expect(log.attributes["exception.slug"] == .string("idocs.command.fetch.failed"))
        #expect(log.attributes["exception.stacktrace"] == nil)
        #expect(log.spanContext?.traceId == root.traceId)
        #expect(root.attributes["error.type"] == .string("not_found"))
        #expect(root.attributes["error.category"] == .string("dependency"))
        #expect(root.attributes["error.expected"] == .bool(false))
    }

    @Test("Unexpected command failures emit one log and no legacy exception span event")
    func commandFailureHasSingleExceptionOwner() async throws {
        let spanExporter = InMemoryExporter()
        let logExporter = TestLogRecordExporter()
        iDocsTelemetry.installForTesting(
            spanExporter: spanExporter,
            logRecordExporter: logExporter
        )
        defer { iDocsTelemetry.shutdown() }

        let previousServiceFactory = CLIEnvironment.serviceFactory
        let previousStderr = CLIEnvironment.writeStderr
        defer {
            CLIEnvironment.serviceFactory = previousServiceFactory
            CLIEnvironment.writeStderr = previousStderr
        }
        CLIEnvironment.serviceFactory = {
            MockDocumentationAdapter(
                errorToThrow: .networkError(message: "token=/Users/snow/private")
            )
        }
        CLIEnvironment.writeStderr = { _ in }

        await iDocsTelemetry.withRootSpan(
            arguments: ["idocs", "search", "private query"],
            serviceVersion: "1.0.0",
            environment: [:]
        ) {
            let exitCode = await CLIExecutor.runSearch(query: "private query")
            #expect(exitCode == 1)
            iDocsTelemetry.setExitCode(exitCode)
        }
        iDocsTelemetry.flush()

        let logs = logExporter.getFinishedLogRecords()
        #expect(logs.count == 1)
        #expect(logs.first?.attributes["exception.message"] == .string("Documentation search failed."))
        let command = try #require(
            spanExporter.getFinishedSpanItems().first { $0.name == "idocs.command.search" }
        )
        #expect(command.events.allSatisfy { $0.name != "exception" })
        #expect(command.attributes["error.type"] == .string("network_unavailable"))
    }

    @Test("Expected command failures mark spans without exception logs")
    func expectedCommandFailureDoesNotEmitException() async throws {
        let spanExporter = InMemoryExporter()
        let logExporter = TestLogRecordExporter()
        iDocsTelemetry.installForTesting(
            spanExporter: spanExporter,
            logRecordExporter: logExporter
        )
        defer { iDocsTelemetry.shutdown() }

        let previousServiceFactory = CLIEnvironment.serviceFactory
        let previousStderr = CLIEnvironment.writeStderr
        defer {
            CLIEnvironment.serviceFactory = previousServiceFactory
            CLIEnvironment.writeStderr = previousStderr
        }
        CLIEnvironment.serviceFactory = {
            MockDocumentationAdapter(errorToThrow: .notFound(id: "/private/path"))
        }
        CLIEnvironment.writeStderr = { _ in }

        await iDocsTelemetry.withRootSpan(
            arguments: ["idocs", "fetch", "/private/path"],
            serviceVersion: "1.0.0",
            environment: [:]
        ) {
            let exitCode = await CLIExecutor.runFetch(id: "/private/path")
            #expect(exitCode == 1)
            iDocsTelemetry.setExitCode(exitCode)
        }
        iDocsTelemetry.flush()

        #expect(logExporter.getFinishedLogRecords().isEmpty)
        let command = try #require(
            spanExporter.getFinishedSpanItems().first { $0.name == "idocs.command.fetch" }
        )
        #expect(command.attributes["error.type"] == .string("not_found"))
        #expect(command.attributes["error.expected"] == .bool(true))
    }

    @Test("Raw telemetry fields are denied before export")
    func rawTelemetryFieldsAreDenied() async throws {
        let exporter = InMemoryExporter()
        iDocsTelemetry.installForTesting(spanExporter: exporter)
        defer { iDocsTelemetry.shutdown() }

        await iDocsTelemetry.withRootSpan(
            arguments: ["idocs", "search", "private query"],
            serviceVersion: "1.0.0",
            environment: [:]
        ) {
            await iDocsTelemetry.withSpan(
                "idocs.pipeline",
                attributes: [
                    "idocs.query": .string("private query"),
                    "idocs.result.count": .int(1)
                ]
            ) {}
            iDocsTelemetry.setAttributes([
                "idocs.query": .string("private query"),
                "idocs.path": .string("/Users/snow/private"),
                "idocs.caller": .string("user@example.com"),
                "idocs.result.count": .int(1)
            ])
            iDocsTelemetry.addEvent(
                "idocs.stage",
                attributes: [
                    "idocs.stage.reason": .string("failed at /Users/snow/private"),
                    "idocs.stage.reason_code": .string("not_found")
                ]
            )
        }
        iDocsTelemetry.flush()

        let root = try #require(exporter.getFinishedSpanItems().first { $0.name == "idocs" })
        #expect(root.attributes["idocs.query"] == nil)
        #expect(root.attributes["idocs.path"] == nil)
        #expect(root.attributes["idocs.caller"] == nil)
        #expect(root.attributes["idocs.result.count"] == .int(1))
        let event = try #require(root.events.first)
        #expect(event.attributes["idocs.stage.reason"] == nil)
        #expect(event.attributes["idocs.stage.reason_code"] == .string("not_found"))
        let child = try #require(
            exporter.getFinishedSpanItems().first { $0.name == "idocs.pipeline" }
        )
        #expect(child.attributes["idocs.query"] == nil)
        #expect(child.attributes["idocs.result.count"] == .int(1))
    }

    @Test("HTTP dependency spans use CLIENT kind and privacy-safe route data")
    func httpDependencySpanContract() async throws {
        let exporter = InMemoryExporter()
        iDocsTelemetry.installForTesting(spanExporter: exporter)
        defer { iDocsTelemetry.shutdown() }

        await iDocsTelemetry.withRootSpan(
            arguments: ["idocs", "fetch", "/private/path"],
            serviceVersion: "1.0.0",
            environment: [:]
        ) {
            await iDocsTelemetry.withHTTPClientSpan(
                method: "GET",
                url: URL(string: "https://developer.apple.com/tutorials/data/private.json?token=secret")!,
                resendCount: 1
            ) {
                iDocsTelemetry.recordHTTPResponse(statusCode: 200)
            }
        }
        iDocsTelemetry.flush()

        let span = try #require(exporter.getFinishedSpanItems().first { $0.name == "GET" })
        #expect(span.kind == .client)
        #expect(span.attributes["http.request.method"] == .string("GET"))
        #expect(span.attributes["server.address"] == .string("developer.apple.com"))
        #expect(span.attributes["url.full"] == .string("https://developer.apple.com/<redacted>"))
        #expect(span.attributes["http.request.resend_count"] == .int(1))
        #expect(span.attributes["http.response.status_code"] == .int(200))
    }

    @Test("Subprocess dependency spans follow CLI caller semantics")
    func subprocessSpanContract() async throws {
        let exporter = InMemoryExporter()
        iDocsTelemetry.installForTesting(spanExporter: exporter)
        defer { iDocsTelemetry.shutdown() }

        await iDocsTelemetry.withRootSpan(
            arguments: ["idocs", "search", "private query"],
            serviceVersion: "1.0.0",
            environment: [:]
        ) {
            await iDocsTelemetry.withProcessSpan(
                executableName: "mdfind",
                arguments: ["mdfind", "private query"]
            ) {
                iDocsTelemetry.setAttributes([
                    "process.pid": .int(123),
                    "process.exit.code": .int(0)
                ])
            }
        }
        iDocsTelemetry.flush()

        let span = try #require(exporter.getFinishedSpanItems().first { $0.name == "mdfind" })
        #expect(span.kind == .client)
        #expect(span.attributes["process.executable.name"] == .string("mdfind"))
        #expect(span.attributes["process.pid"] == .int(123))
        #expect(span.attributes["process.exit.code"] == .int(0))
        #expect(span.attributes["process.command_args"] == .array(AttributeArray(values: [
            .string("mdfind"),
            .string("<argument>")
        ])))
    }

    @Test("Sosumi transport creates an HTTP CLIENT span")
    func sosumiTransportIsInstrumented() async throws {
        let exporter = InMemoryExporter()
        iDocsTelemetry.installForTesting(spanExporter: exporter)
        defer { iDocsTelemetry.shutdown() }

        let responseURL = URL(string: "https://sosumi.ai/api/search")!
        let session = MockNetworkSession(
            stubbedData: Data(#"{"query":"SwiftUI","results":[]}"#.utf8),
            stubbedResponse: HTTPURLResponse(
                url: responseURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
        )
        let api = SosumiAPI(session: session)

        try await iDocsTelemetry.withRootSpan(
            arguments: ["idocs", "search", "SwiftUI"],
            serviceVersion: "1.0.0",
            environment: [:]
        ) {
            _ = try await api.search(query: "SwiftUI")
        }
        iDocsTelemetry.flush()

        let span = try #require(exporter.getFinishedSpanItems().first { $0.name == "GET" })
        #expect(span.kind == .client)
        #expect(span.attributes["server.address"] == .string("sosumi.ai"))
        #expect(span.attributes["http.response.status_code"] == .int(200))
    }

    @Test("Spotlight provider creates an mdfind CLIENT span")
    func spotlightProviderIsInstrumented() async throws {
        let exporter = InMemoryExporter()
        iDocsTelemetry.installForTesting(spanExporter: exporter)
        defer { iDocsTelemetry.shutdown() }

        let provider = SpotlightSearchProvider(timeoutSeconds: 0.05)
        await iDocsTelemetry.withRootSpan(
            arguments: ["idocs", "search", "SwiftUI"],
            serviceVersion: "1.0.0",
            environment: [:]
        ) {
            _ = try? await provider.search(query: "SwiftUI")
        }
        iDocsTelemetry.flush()

        let span = try #require(exporter.getFinishedSpanItems().first { $0.name == "mdfind" })
        #expect(span.kind == .client)
        #expect(span.attributes["process.pid"] != nil)
        #expect(span.attributes["process.exit.code"] != nil)
    }

    @Test("Manual ArgumentParser execution returns errors without terminating the process")
    func manualCLIExecutionPreservesPresentation() async {
        final class OutputCapture: @unchecked Sendable {
            var stdout: [String] = []
            var stderr: [String] = []
        }

        let capture = OutputCapture()
        let previousStdout = CLIEnvironment.writeStdout
        let previousStderr = CLIEnvironment.writeStderr
        defer {
            CLIEnvironment.writeStdout = previousStdout
            CLIEnvironment.writeStderr = previousStderr
        }
        CLIEnvironment.writeStdout = { capture.stdout.append($0) }
        CLIEnvironment.writeStderr = { capture.stderr.append($0) }

        let code = await iDocsCLI.execute(arguments: ["unknown-command"])

        #expect(code != 0)
        #expect(capture.stdout.isEmpty)
        #expect(capture.stderr.joined(separator: "\n").contains("unknown-command"))
    }

    @Test("CLI parse failures finalize the root span as expected invalid input")
    func cliParseFailureFinalizesRootSpan() async throws {
        let exporter = InMemoryExporter()
        iDocsTelemetry.installForTesting(spanExporter: exporter)
        defer { iDocsTelemetry.shutdown() }

        let previousStderr = CLIEnvironment.writeStderr
        defer { CLIEnvironment.writeStderr = previousStderr }
        CLIEnvironment.writeStderr = { _ in }

        await iDocsTelemetry.withRootSpan(
            arguments: ["idocs", "unknown-command"],
            serviceVersion: "1.0.0",
            environment: [:]
        ) {
            _ = await iDocsCLI.execute(arguments: ["unknown-command"])
        }
        iDocsTelemetry.flush()

        let root = try #require(exporter.getFinishedSpanItems().first { $0.name == "idocs" })
        #expect(root.attributes["process.exit.code"] != .int(0))
        #expect(root.attributes["error.type"] == .string("invalid_argument"))
        #expect(root.attributes["error.category"] == .string("user"))
        #expect(root.attributes["error.expected"] == .bool(true))
    }

    @Test("Non-zero exit code sets span status to error")
    func nonZeroExitCodeSetsErrorStatus() async throws {
        let exporter = InMemoryExporter()
        iDocsTelemetry.installForTesting(spanExporter: exporter)
        defer { iDocsTelemetry.shutdown() }

        await iDocsTelemetry.withRootSpan(
            arguments: ["idocs"],
            serviceVersion: "1.0.0",
            environment: [:]
        ) {
            iDocsTelemetry.setExitCode(1)
        }
        iDocsTelemetry.flush()

        let spans = exporter.getFinishedSpanItems()
        let root = try #require(spans.first { $0.name == "idocs" })
        #expect(root.attributes["process.exit.code"] == .int(1))
        
        switch root.status {
        case .error(let description):
            #expect(description.contains("Process exited with non-zero code"))
        default:
            Issue.record("Expected span status to be error, but got: \(root.status)")
        }
    }

    @Test("CLI search emits command span without changing existing output")
    func cliSearchCommandSpan() async throws {
        let exporter = InMemoryExporter()
        iDocsTelemetry.installForTesting(spanExporter: exporter)
        defer { iDocsTelemetry.shutdown() }

        final class OutputCapture: @unchecked Sendable {
            var stdout: [String] = []
            var stderr: [String] = []
        }

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

        await iDocsTelemetry.withRootSpan(
            arguments: ["/tmp/idocs", "search", "SwiftUI"],
            serviceVersion: "1.2.3",
            environment: [:]
        ) {
            let code = await CLIExecutor.runSearch(
                query: "SwiftUI",
                outputFormat: .json,
                callerID: "skill.swiftui-engineering"
            )
            #expect(code == 0)
        }
        iDocsTelemetry.flush()

        let payloadData = try #require(capture.stdout.first?.data(using: .utf8))
        let payload = try JSONDecoder().decode(CLICommandPayload.self, from: payloadData)
        #expect(payload.command == "search")
        #expect(payload.caller == "skill.swiftui-engineering")

        let spans = exporter.getFinishedSpanItems()
        let command = try #require(spans.first { $0.name == "idocs.command.search" })
        #expect(command.attributes["process.exit.code"] == .int(0))
        #expect(command.attributes["idocs.output.format"] == .string("json"))
        #expect(command.attributes["idocs.caller"] == nil)
        #expect(command.attributes["idocs.caller.category"] == .string("skill"))
    }
}

private final class TestLogRecordExporter: LogRecordExporter, @unchecked Sendable {
    private let lock = NSLock()
    private var records: [ReadableLogRecord] = []

    func getFinishedLogRecords() -> [ReadableLogRecord] {
        lock.withLock { records }
    }

    func export(
        logRecords: [ReadableLogRecord],
        explicitTimeout: TimeInterval? = nil
    ) -> ExportResult {
        lock.withLock {
            records.append(contentsOf: logRecords)
        }
        return .success
    }

    func shutdown(explicitTimeout: TimeInterval? = nil) {}

    func forceFlush(explicitTimeout: TimeInterval? = nil) -> ExportResult {
        .success
    }
}
