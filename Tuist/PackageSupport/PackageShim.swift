import ArgumentParser
import InMemoryExporter
import Logging
import OpenTelemetryApi
import OpenTelemetryProtocolExporterHttp
import OpenTelemetrySdk

enum PackageShim {
    static func touch() {
        _ = Logger.self
        _ = CommandConfiguration.self
        _ = InMemoryExporter.self
        _ = OpenTelemetry.self
        _ = OtlpHttpTraceExporter.self
        _ = TracerProviderBuilder.self
    }
}
