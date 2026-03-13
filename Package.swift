// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "iDocs",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "iDocs", targets: ["iDocs"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.3.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "iDocs",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Sources/iDocs"
        ),
        .testTarget(
            name: "iDocsTests",
            dependencies: ["iDocs"],
            path: "Tests/iDocsTests"
        )
    ]
)
