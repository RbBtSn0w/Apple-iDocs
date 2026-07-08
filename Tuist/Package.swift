// swift-tools-version: 6.0
import PackageDescription

#if TUIST
    import ProjectDescription

    let packageSettings = PackageSettings(
        productTypes: [
            "Logging": .framework,
            "ArgumentParser": .staticFramework,
            "OpenTelemetryApi": .framework,
            "OpenTelemetrySdk": .framework,
            "OpenTelemetryProtocolExporterHTTP": .framework,
            "InMemoryExporter": .framework
        ]
    )
#endif

let package = Package(
    name: "iDocsDependencies",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift-core.git", exact: "2.5.1"),
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift.git", exact: "2.4.1")
    ],
    targets: [
        .target(
            name: "PackageShim",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
                .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
                .product(name: "InMemoryExporter", package: "opentelemetry-swift")
            ],
            path: "PackageSupport"
        )
    ]
)
