import Foundation
import InMemoryExporter
import OpenTelemetryApi
import Testing
@testable import iDocsApp
import iDocsAdapter
import iDocsTelemetry

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
            .string("SwiftUI")
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
        #expect(command.attributes["idocs.caller"] == .string("skill.swiftui-engineering"))
    }
}
