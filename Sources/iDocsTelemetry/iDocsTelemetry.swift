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

public struct TelemetryFailureDescriptor: Sendable, Equatable {
    public let errorType: String
    public let category: String
    public let slug: String
    public let expected: Bool
    public let exceptionType: String
    public let safeMessage: String

    public init(
        errorType: String,
        category: String,
        slug: String,
        expected: Bool,
        exceptionType: String,
        safeMessage: String
    ) {
        self.errorType = errorType
        self.category = category
        self.slug = slug
        self.expected = expected
        self.exceptionType = exceptionType
        self.safeMessage = safeMessage
    }
}

public enum iDocsTelemetry {
    public static let defaultTracesEndpoint = URL(string: "https://telemetry-gateway.hamiltonsnow.workers.dev/v1/traces")!
    static let gatewayOrigins = Set([
        "https://telemetry-gateway-development.hamiltonsnow.workers.dev",
        "https://telemetry-gateway-staging.hamiltonsnow.workers.dev",
        "https://telemetry-gateway.hamiltonsnow.workers.dev",
    ])
    static let gatewayProfile = ("otel-gateway-profile", "anonymous-client-v1")
    public static let serviceName = "idocs"
    public static let testServiceName = "idocs-test"
    public static let telemetryEnvironmentVariable = "IDOCS_TELEMETRY_ENVIRONMENT"

    private static let lock = NSLock()
    private nonisolated(unsafe) static var runtime = RuntimeState(
        tracerProvider: nil,
        tracer: nil
    )

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
                runtime = RuntimeState(
                    tracerProvider: nil,
                    tracer: nil
                )
            }
            return
        }

        let resource = buildResource(serviceVersion: serviceVersion, environment: environment)
        let tracesEndpoint = resolveTracesEndpoint(environment: environment)
        let traceExporter = OtlpHttpTraceExporter(
            endpoint: tracesEndpoint,
            config: OtlpConfiguration(
                timeout: 0.15,
                compression: .gzip,
                headers: gatewayHeaders(for: tracesEndpoint),
                exportAsJson: false
            ),
            envVarHeaders: []
        )
        let traceProcessor = BatchSpanProcessor(
            spanExporter: traceExporter,
            scheduleDelay: 0.05,
            exportTimeout: 0.15,
            maxQueueSize: 256,
            maxExportBatchSize: 64
        )
        let provider = TracerProviderBuilder()
            .with(resource: resource)
            .add(spanProcessor: traceProcessor)
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
            runtime = RuntimeState(
                tracerProvider: provider,
                tracer: tracer
            )
        }
    }

    public static func installForTesting(
        spanExporter: SpanExporter,
        logRecordExporter _: LogRecordExporter? = nil,
        serviceVersion: String = "test"
    ) {
        let resource = Resource(attributes: [
            "service.name": AttributeValue(testServiceName),
            "service.version": AttributeValue(serviceVersion),
            "service.namespace": AttributeValue("com.snow")
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
            runtime = RuntimeState(
                tracerProvider: provider,
                tracer: tracer
            )
        }
    }

    public static func resetForTesting() {
        lock.withLock {
            runtime = RuntimeState(
                tracerProvider: nil,
                tracer: nil
            )
        }
    }

    public static func shutdown() {
        let currentRuntime = lock.withLock { runtime }
        currentRuntime.tracerProvider?.forceFlush(timeout: 0.2)
        currentRuntime.tracerProvider?.shutdown()
        lock.withLock {
            runtime = RuntimeState(
                tracerProvider: nil,
                tracer: nil
            )
        }
    }

    public static func flush(timeout: TimeInterval = 0.2) {
        let currentRuntime = lock.withLock { runtime }
        currentRuntime.tracerProvider?.forceFlush(timeout: timeout)
    }

    public static func resolveTracesEndpoint(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        resolveEndpoint(
            signalEnvironmentKey: "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT",
            signalPath: "v1/traces",
            fallback: defaultTracesEndpoint,
            environment: environment
        )
    }

    static func gatewayHeaders(for endpoint: URL) -> [(String, String)]? {
        guard endpoint.scheme?.lowercased() == "https",
              (endpoint.port ?? 443) == 443,
              gatewayOrigins.contains("https://\(endpoint.host?.lowercased() ?? "")")
        else {
            return nil
        }
        return [gatewayProfile]
    }

    public static func telemetryDisabled(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["DISABLE_TELEMETRY"] == "1" || environment["DO_NOT_TRACK"] == "1"
    }

    public static func callerCategory(_ callerID: String) -> String {
        let normalized = callerID.lowercased()
        if normalized.hasPrefix("skill.") {
            return "skill"
        }
        if normalized.hasPrefix("mcp.") {
            return "mcp"
        }
        if normalized.hasPrefix("benchmark.") {
            return "benchmark"
        }
        if normalized.hasPrefix("automation.") || normalized.hasPrefix("ci.") {
            return "automation"
        }
        return "unknown"
    }

    public static func reasonCode(_ value: String) -> String {
        if value.hasPrefix("remote_decode_failed.") {
            return "remote_decode_failed"
        }
        if value.hasPrefix("remote_decode_partial.") {
            return "remote_decode_partial"
        }
        if value.hasPrefix("http_"),
           value.dropFirst(5).count == 3,
           value.dropFirst(5).allSatisfy(\.isNumber) {
            return "http_error"
        }
        return allowedReasonCodes.contains(value) ? value : "other"
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
        for (key, value) in attributes where !deniedAttributeKeys.contains(key) {
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
            attributes: attributes
                .filter { !deniedAttributeKeys.contains($0.key) }
                .mapValues(\.otelValue)
        )
    }

    public static func setExitCode(_ exitCode: Int32) {
        setAttributes(["process.exit.code": .int(Int(exitCode))])
        if exitCode != 0 {
            if let span = OpenTelemetry.instance.contextProvider.activeSpan, span.isRecording {
                span.setAttribute(key: "error", value: AttributeValue(true))
                span.setAttribute(key: "error.type", value: AttributeValue("_OTHER"))
                span.status = .error(description: "Process exited with non-zero code: \(exitCode)")
            }
        }
    }

    public static func recordError(_ error: Error, type override: String? = nil) {
        let typeName = override ?? String(describing: Swift.type(of: error))
        markFailure(
            TelemetryFailureDescriptor(
                errorType: typeName,
                category: "internal",
                slug: "idocs.operation.failed",
                expected: false,
                exceptionType: typeName,
                safeMessage: "iDocs operation failed."
            )
        )
    }

    public static func markFailure(_ descriptor: TelemetryFailureDescriptor) {
        guard let span = OpenTelemetry.instance.contextProvider.activeSpan, span.isRecording else {
            return
        }
        span.setAttribute(key: "error", value: AttributeValue(true))
        span.setAttribute(key: "error.type", value: AttributeValue(descriptor.errorType))
        span.setAttribute(
            key: "error.category",
            value: AttributeValue(normalizedErrorCategory(descriptor.category))
        )
        span.setAttribute(key: "error.expected", value: AttributeValue(descriptor.expected))
        span.setAttribute(key: "exception.slug", value: AttributeValue(descriptor.slug))
        span.status = .error(description: descriptor.errorType)
    }

    public static func captureException(_ descriptor: TelemetryFailureDescriptor) {
        markFailure(descriptor)
    }

    @discardableResult
    public static func withHTTPClientSpan<T: Sendable>(
        method: String,
        url: URL,
        resendCount: Int = 0,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        guard let tracer = lock.withLock({ runtime.tracer }),
              let scheme = url.scheme,
              let host = url.host else {
            return try await operation()
        }

        let normalizedMethod = method.uppercased()
        let builder = tracer.spanBuilder(spanName: normalizedMethod)
            .setActive(true)
            .setSpanKind(spanKind: .client)
            .setAttribute(key: "http.request.method", value: AttributeValue(normalizedMethod))
            .setAttribute(key: "server.address", value: AttributeValue(host))
            .setAttribute(
                key: "url.full",
                value: AttributeValue(redactedURLAuthority(scheme: scheme, host: host, url: url))
            )
            .setAttribute(
                key: "http.request.resend_count",
                value: AttributeValue(resendCount)
            )

        if let port = url.port,
           !((scheme == "https" && port == 443) || (scheme == "http" && port == 80)) {
            _ = builder.setAttribute(key: "server.port", value: AttributeValue(port))
        }

        return try await builder.withActiveSpan { _ in
            do {
                return try await operation()
            } catch {
                recordError(error)
                throw error
            }
        }
    }

    public static func recordHTTPResponse(statusCode: Int) {
        setAttributes(["http.response.status_code": .int(statusCode)])
        guard statusCode >= 400,
              let span = OpenTelemetry.instance.contextProvider.activeSpan,
              span.isRecording else {
            return
        }
        span.setAttribute(key: "error", value: AttributeValue(true))
        span.setAttribute(key: "error.type", value: AttributeValue(String(statusCode)))
        span.status = .error(description: "HTTP \(statusCode)")
    }

    @discardableResult
    public static func withProcessSpan<T>(
        executableName: String,
        arguments: [String],
        operation: () async throws -> T
    ) async rethrows -> T {
        guard let tracer = lock.withLock({ runtime.tracer }) else {
            return try await operation()
        }

        let builder = tracer.spanBuilder(spanName: executableName)
            .setActive(true)
            .setSpanKind(spanKind: .client)
            .setAttribute(
                key: "process.executable.name",
                value: AttributeValue(executableName)
            )
            .setAttribute(
                key: "process.command_args",
                value: AttributeValue(sanitizeSubprocessArgs(arguments))
            )

        return try await builder.withActiveSpan { _ in
            do {
                return try await operation()
            } catch {
                recordError(error)
                throw error
            }
        }
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
            do {
                return try await operation()
            } catch {
                recordError(error)
                throw error
            }
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

        for (key, value) in attributes where !deniedAttributeKeys.contains(key) {
            _ = builder.setAttribute(key: key, value: value.otelValue)
        }

        return try await builder.withActiveSpan { _ in
            try await operation()
        }
    }

    public static func extractParentSpanContext(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> SpanContext? {
        guard let traceparent = nonEmpty(environment["TRACEPARENT"]) ?? nonEmpty(environment["traceparent"]) else {
            return nil
        }
        let carrier = ["traceparent": traceparent]
        return W3CTraceContextPropagator().extract(carrier: carrier, getter: DictionaryGetter())
    }

    static func buildResource(
        serviceVersion: String,
        environment: [String: String]
    ) -> Resource {
        let attributes: [String: AttributeValue] = [
            "service.name": AttributeValue(serviceName),
            "service.version": AttributeValue(serviceVersion),
            "service.namespace": AttributeValue("com.snow"),
            "idocs.telemetry.schema.version": AttributeValue("2")
        ]
        _ = environment
        return Resource(attributes: attributes)
    }

    private static func executableName(arguments: [String]) -> String {
        guard let first = arguments.first, !first.isEmpty else {
            return ProcessInfo.processInfo.processName
        }
        return URL(fileURLWithPath: first).lastPathComponent
    }

    private static func redactedURLAuthority(scheme: String, host: String, url: URL) -> String {
        let isDefaultPort = (scheme == "https" && url.port == 443)
            || (scheme == "http" && url.port == 80)
        guard let port = url.port, !isDefaultPort else {
            return "\(scheme)://\(host)/<redacted>"
        }

        let authorityHost = host.contains(":") ? "[\(host)]" : host
        return "\(scheme)://\(authorityHost):\(port)/<redacted>"
    }

    private static func sanitizeArgs(_ arguments: [String]) -> [String] {
        guard !arguments.isEmpty else { return [] }
        var sanitized = [URL(fileURLWithPath: arguments[0]).lastPathComponent]
        var index = 1
        var retainedCommand = false

        while index < arguments.count {
            let argument = arguments[index]
            if argument.hasPrefix("-") {
                let components = argument.split(separator: "=", maxSplits: 1)
                let option = String(components[0])
                sanitized.append("<option>")

                if components.count == 2 {
                    sanitized.append(placeholder(for: option))
                } else if optionRequiresValue(option), index + 1 < arguments.count {
                    index += 1
                    sanitized.append(placeholder(for: option))
                }
            } else if !retainedCommand {
                sanitized.append(
                    knownCommands.contains(argument) ? argument : "<argument>"
                )
                retainedCommand = true
            } else {
                sanitized.append("<argument>")
            }
            index += 1
        }
        return sanitized
    }

    private static let knownCommands: Set<String> = [
        "search",
        "resolve",
        "fetch",
        "list"
    ]

    private static func optionRequiresValue(_ option: String) -> Bool {
        !["--json", "--version", "--help", "-h", "-v"].contains(option)
    }

    private static func placeholder(for option: String) -> String {
        switch option {
        case "--cache-path", "--usage-log-path", "--xcode-documentation-cache-path":
            return "<path>"
        case "--caller":
            return "<caller>"
        case "--token", "--api-key":
            return "<redacted>"
        default:
            return "<value>"
        }
    }

    private static func sanitizeSubprocessArgs(_ arguments: [String]) -> [String] {
        guard let executable = arguments.first else {
            return []
        }
        return [URL(fileURLWithPath: executable).lastPathComponent]
            + arguments.dropFirst().map { argument in
                argument.hasPrefix("-") ? "<option>" : "<argument>"
            }
    }

    private static func resolveEndpoint(
        signalEnvironmentKey: String,
        signalPath: String,
        fallback: URL,
        environment: [String: String]
    ) -> URL {
        if let signalEndpoint = nonEmpty(environment[signalEnvironmentKey]),
           let url = URL(string: signalEndpoint) {
            return url
        }

        if let base = nonEmpty(environment["OTEL_EXPORTER_OTLP_ENDPOINT"]),
           var components = URLComponents(string: base) {
            let existingPath = components.path.trimmingCharacters(
                in: CharacterSet(charactersIn: "/")
            )
            if existingPath.hasSuffix(signalPath) {
                components.path = "/\(existingPath)"
            } else {
                components.path = existingPath.isEmpty
                    ? "/\(signalPath)"
                    : "/\(existingPath)/\(signalPath)"
            }
            if let url = components.url {
                return url
            }
        }

        return fallback
    }

    private static let deniedAttributeKeys: Set<String> = [
        "idocs.query",
        "idocs.path",
        "idocs.query_attempt",
        "idocs.caller",
        "idocs.stage.reason",
        "idocs.category_filter"
    ]

    private static let allowedReasonCodes: Set<String> = [
        "cache_miss",
        "candidate_recovery",
        "corrupt_cache_entry",
        "empty_body",
        "fetch_failed",
        "fetch_verified",
        "invalid_response",
        "invalid_url",
        "local_decode_failed",
        "local_docs_unavailable",
        "local_error",
        "local_fetch_failed",
        "local_module_fallback",
        "local_no_results",
        "low_confidence_remote_results",
        "max_retries_reached",
        "member_kind_mismatch",
        "no_candidates",
        "no_fetch_verified_candidate",
        "not_found",
        "opaque_miss_query",
        "remote_decode_failed",
        "remote_decode_partial",
        "remote_empty_body",
        "remote_error",
        "remote_http_error",
        "remote_invalid_response",
        "remote_invalid_url",
        "remote_network_failure",
        "remote_no_results",
        "remote_permission_denied",
        "remote_timeout",
        "unsupported_source_type"
    ]

    private static func normalizedErrorCategory(_ value: String) -> String {
        switch value {
        case "user", "dependency", "timeout", "rate_limit", "internal":
            return value
        default:
            return "internal"
        }
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

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
