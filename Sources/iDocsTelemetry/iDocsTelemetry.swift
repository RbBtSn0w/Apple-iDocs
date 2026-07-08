import Foundation
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
import OpenTelemetryProtocolExporterHttp
import OpenTelemetrySdk

#if canImport(Darwin)
import Darwin
#endif

public enum TelemetryAttributeValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case stringArray([String])

    fileprivate var otelValue: AttributeValue {
        switch self {
        case .string(let value):
            return AttributeValue(value)
        case .int(let value):
            return AttributeValue(value)
        case .double(let value):
            return AttributeValue(value)
        case .bool(let value):
            return AttributeValue(value)
        case .stringArray(let value):
            return AttributeValue(value)
        }
    }
}

public enum iDocsTelemetry {
    public static let defaultTracesEndpoint = URL(string: "https://telemetry-gateway.hamiltonsnow.workers.dev/v1/traces")!
    public static let serviceName = "idocs"
    public static let testServiceName = "idocs-test"
    public static let telemetryEnvironmentVariable = "IDOCS_TELEMETRY_ENVIRONMENT"

    private static let lock = NSLock()
    private nonisolated(unsafe) static var runtime = RuntimeState(tracerProvider: nil, tracer: nil)

    private struct RuntimeState: @unchecked Sendable {
        let tracerProvider: TracerProviderSdk?
        let tracer: Tracer?
    }

    public static func bootstrap(
        serviceVersion: String,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        guard !telemetryDisabled(environment: environment) else {
            lock.withLock {
                runtime = RuntimeState(tracerProvider: nil, tracer: nil)
            }
            return
        }

        let endpoint = resolveTracesEndpoint(environment: environment)
        let resource = buildResource(serviceVersion: serviceVersion, environment: environment)
        let exporter = OtlpHttpTraceExporter(
            endpoint: endpoint,
            config: OtlpConfiguration(
                timeout: 0.15,
                compression: .gzip,
                headers: nil,
                exportAsJson: false
            )
        )
        let processor = BatchSpanProcessor(
            spanExporter: exporter,
            scheduleDelay: 0.05,
            exportTimeout: 0.15,
            maxQueueSize: 256,
            maxExportBatchSize: 64
        )
        let provider = TracerProviderBuilder()
            .with(resource: resource)
            .add(spanProcessor: processor)
            .build()
        OpenTelemetry.registerTracerProvider(tracerProvider: provider)
        OpenTelemetry.registerFeedbackHandler { _ in
            // Exporter diagnostics stay off the CLI surface.
        }

        let tracer = provider.get(
            instrumentationName: "com.snow.idocs.telemetry",
            instrumentationVersion: serviceVersion
        )
        lock.withLock {
            runtime = RuntimeState(tracerProvider: provider, tracer: tracer)
        }
    }

    public static func installForTesting(
        spanExporter: SpanExporter,
        serviceVersion: String = "test"
    ) {
        let resource = Resource(attributes: [
            "service.name": AttributeValue(testServiceName),
            "service.version": AttributeValue(serviceVersion),
            "service.namespace": AttributeValue("com.snow"),
            "deployment.environment": AttributeValue("test")
        ])
        let provider = TracerProviderBuilder()
            .with(resource: resource)
            .add(spanProcessor: SimpleSpanProcessor(spanExporter: spanExporter))
            .build()
        OpenTelemetry.registerTracerProvider(tracerProvider: provider)
        OpenTelemetry.registerFeedbackHandler { _ in }
        let tracer = provider.get(
            instrumentationName: "com.snow.idocs.telemetry",
            instrumentationVersion: serviceVersion
        )
        lock.withLock {
            runtime = RuntimeState(tracerProvider: provider, tracer: tracer)
        }
    }

    public static func resetForTesting() {
        lock.withLock {
            runtime = RuntimeState(tracerProvider: nil, tracer: nil)
        }
    }

    public static func shutdown() {
        let provider = lock.withLock { runtime.tracerProvider }
        provider?.forceFlush(timeout: 0.2)
        provider?.shutdown()
        lock.withLock {
            runtime = RuntimeState(tracerProvider: nil, tracer: nil)
        }
    }

    public static func flush(timeout: TimeInterval = 0.2) {
        let provider = lock.withLock { runtime.tracerProvider }
        provider?.forceFlush(timeout: timeout)
    }

    public static func resolveTracesEndpoint(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        if let traces = nonEmpty(environment["OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"]),
           let url = URL(string: traces) {
            return url
        }

        if let base = nonEmpty(environment["OTEL_EXPORTER_OTLP_ENDPOINT"]),
           var components = URLComponents(string: base) {
            let existingPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            components.path = existingPath.isEmpty ? "/v1/traces" : "/\(existingPath)/v1/traces"
            if let url = components.url {
                return url
            }
        }

        return defaultTracesEndpoint
    }

    public static func telemetryDisabled(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["DISABLE_TELEMETRY"] == "1" || environment["DO_NOT_TRACK"] == "1"
    }

    public static func currentSpanName() -> String? {
        guard let span = OpenTelemetry.instance.contextProvider.activeSpan, span.isRecording else {
            return nil
        }
        return span.name
    }

    public static func setAttributes(_ attributes: [String: TelemetryAttributeValue]) {
        guard let span = OpenTelemetry.instance.contextProvider.activeSpan, span.isRecording else {
            return
        }
        for (key, value) in attributes {
            span.setAttribute(key: key, value: value.otelValue)
        }
    }

    public static func addEvent(
        _ name: String,
        attributes: [String: TelemetryAttributeValue] = [:]
    ) {
        guard let span = OpenTelemetry.instance.contextProvider.activeSpan, span.isRecording else {
            return
        }
        span.addEvent(
            name: name,
            attributes: attributes.mapValues(\.otelValue)
        )
    }

    public static func setExitCode(_ exitCode: Int32) {
        setAttributes(["process.exit.code": .int(Int(exitCode))])
        if exitCode != 0 {
            if let span = OpenTelemetry.instance.contextProvider.activeSpan, span.isRecording {
                span.status = .error(description: "Process exited with non-zero code: \(exitCode)")
            }
        }
    }

    public static func recordError(_ error: Error, type override: String? = nil) {
        guard let span = OpenTelemetry.instance.contextProvider.activeSpan, span.isRecording else {
            return
        }
        let typeName = override ?? String(describing: Swift.type(of: error))
        span.setAttribute(key: "error.type", value: AttributeValue(typeName))
        span.status = .error(description: typeName)
        span.recordException(SanitizedTelemetryError(typeName: typeName))
    }

    @discardableResult
    public static func withRootSpan<T>(
        arguments: [String],
        serviceVersion: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        operation: () async throws -> T
    ) async rethrows -> T {
        let shouldBootstrap = lock.withLock { runtime.tracer == nil }
        if shouldBootstrap {
            bootstrap(serviceVersion: serviceVersion, environment: environment)
        }
        defer {
            if shouldBootstrap {
                shutdown()
            }
        }

        guard let tracer = lock.withLock({ runtime.tracer }) else {
            return try await operation()
        }

        let exeName = executableName(arguments: arguments)
        let builder = tracer.spanBuilder(spanName: exeName)
            .setActive(true)
            .setSpanKind(spanKind: .internal)
            .setAttribute(key: "process.command", value: AttributeValue(exeName))
            .setAttribute(key: "process.command_args", value: AttributeValue(sanitizeArgs(arguments)))
            .setAttribute(key: "process.executable.name", value: AttributeValue(exeName))
            .setAttribute(key: "process.pid", value: AttributeValue(Int(getpid())))
            .setAttribute(key: "process.parent_pid", value: AttributeValue(Int(getppid())))

        if let parent = extractParentSpanContext(environment: environment) {
            _ = builder.setParent(parent)
        } else {
            _ = builder.setNoParent()
        }

        return try await builder.withActiveSpan { _ in
            try await operation()
        }
    }

    @discardableResult
    public static func withSpan<T>(
        _ name: String,
        attributes: [String: TelemetryAttributeValue] = [:],
        operation: () async throws -> T
    ) async rethrows -> T {
        guard let tracer = lock.withLock({ runtime.tracer }) else {
            return try await operation()
        }

        let builder = tracer.spanBuilder(spanName: name)
            .setActive(true)
            .setSpanKind(spanKind: .internal)

        for (key, value) in attributes {
            _ = builder.setAttribute(key: key, value: value.otelValue)
        }

        return try await builder.withActiveSpan { _ in
            try await operation()
        }
    }

    public static func extractParentSpanContext(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> SpanContext? {
        guard let traceparent = nonEmpty(environment["TRACEPARENT"] ?? environment["traceparent"]) else {
            return nil
        }
        let carrier = ["traceparent": traceparent]
        return W3CTraceContextPropagator().extract(carrier: carrier, getter: DictionaryGetter())
    }

    private static func buildResource(
        serviceVersion: String,
        environment: [String: String]
    ) -> Resource {
        var attributes: [String: AttributeValue] = [
            "service.name": AttributeValue(
                environment[telemetryEnvironmentVariable] == "test" ? testServiceName : serviceName
            ),
            "service.version": AttributeValue(serviceVersion),
            "service.namespace": AttributeValue("com.snow")
        ]
        if environment[telemetryEnvironmentVariable] == "test" {
            attributes["deployment.environment"] = AttributeValue("test")
        }
        return EnvVarResource.get(environment: environment).merging(other: Resource(attributes: attributes))
    }

    private static func executableName(arguments: [String]) -> String {
        guard let first = arguments.first, !first.isEmpty else {
            return ProcessInfo.processInfo.processName
        }
        return URL(fileURLWithPath: first).lastPathComponent
    }

    private static func sanitizeArgs(_ arguments: [String]) -> [String] {
        guard !arguments.isEmpty else { return [] }
        var sanitized = [String]()
        sanitized.append(URL(fileURLWithPath: arguments[0]).lastPathComponent)
        for arg in arguments.dropFirst() {
            if arg.hasPrefix("/") || arg.contains("/") || arg.contains("\\") {
                if let url = URL(string: arg), url.scheme != nil {
                    sanitized.append("\(url.scheme ?? "")://\(url.host ?? "")/...")
                } else {
                    sanitized.append("<path>")
                }
            } else if arg.count > 30 && (arg.rangeOfCharacter(from: .alphanumerics.inverted) == nil) {
                sanitized.append("<redacted>")
            } else {
                sanitized.append(arg)
            }
        }
        return sanitized
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

private struct DictionaryGetter: Getter {
    func get(carrier: [String: String], key: String) -> [String]? {
        carrier[key].map { [$0] }
    }
}

private struct SanitizedTelemetryError: LocalizedError {
    let typeName: String

    var errorDescription: String? {
        typeName
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
