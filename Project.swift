import ProjectDescription

let project = Project(
    name: "iDocs",
    targets: [
        .target(
            name: "iDocs",
            destinations: .macOS,
            product: .executable,
            bundleId: "com.snow.idocs",
            deploymentTargets: .macOS("13.0"),
            sources: ["Sources/iDocs/**"],
            dependencies: [
                .external(name: "MCP"),
                .external(name: "ServiceLifecycle"),
                .external(name: "Logging")
            ]
        ),
        .target(
            name: "iDocsTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.snow.idocsTests",
            deploymentTargets: .macOS("13.0"),
            sources: ["Tests/iDocsTests/**"],
            dependencies: [
                .target(name: "iDocs")
            ]
        )
    ]
)
