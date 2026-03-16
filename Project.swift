import ProjectDescription

let settings: Settings = .settings(
    base: [
        "MACOSX_DEPLOYMENT_TARGET": "13.0",
        "SWIFT_VERSION": "6.0",
        "ENABLE_TESTABILITY": "YES"
    ],
    configurations: [
        .debug(name: .debug),
        .release(name: .release)
    ]
)

let project = Project(
    name: "iDocs",
    settings: settings,
    targets: [
        .target(
            name: "iDocsKit",
            destinations: .macOS,
            product: .staticLibrary,
            bundleId: "com.snow.idocs.kit",
            deploymentTargets: .macOS("13.0"),
            sources: [
                "Sources/iDocs/**"
            ],
            dependencies: [
                .external(name: "MCP"),
                .external(name: "ServiceLifecycle"),
                .external(name: "Logging")
            ]
        ),
        .target(
            name: "iDocs",
            destinations: .macOS,
            product: .commandLineTool,
            bundleId: "com.snow.idocs",
            deploymentTargets: .macOS("13.0"),
            sources: ["Sources/iDocs/iDocsServer.swift"],
            dependencies: [
                .target(name: "iDocsKit")
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
                .target(name: "iDocsKit")
            ]
        )
    ]
)
