import ProjectDescription

let settings: Settings = .settings(
    base: [
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
            product: .framework,
            bundleId: "com.snow.idocs.kit",
            deploymentTargets: .macOS("13.0"),
            sources: [
                "Sources/iDocs/Cache/**",
                "Sources/iDocs/DataSources/**",
                "Sources/iDocs/Protocols/**",
                "Sources/iDocs/Rendering/**",
                "Sources/iDocs/Tools/**",
                "Sources/iDocs/Utils/**",
                "Sources/iDocsKit/**"
            ],
            dependencies: [
                .external(name: "Logging")
            ]
        ),
        .target(
            name: "iDocsAdapter",
            destinations: .macOS,
            product: .framework,
            bundleId: "com.snow.idocs.adapter",
            deploymentTargets: .macOS("13.0"),
            sources: ["Sources/iDocsAdapter/**"],
            dependencies: [
                .target(name: "iDocsKit")
            ]
        ),
        .target(
            name: "iDocsApp",
            destinations: .macOS,
            product: .staticLibrary,
            bundleId: "com.snow.idocs.app",
            deploymentTargets: .macOS("13.0"),
            sources: [
                "Sources/iDocs/Commands/**"
            ],
            dependencies: [
                .target(name: "iDocsAdapter"),
                .external(name: "ArgumentParser")
            ]
        ),
        .target(
            name: "iDocs",
            destinations: .macOS,
            product: .commandLineTool,
            bundleId: "com.snow.idocs",
            deploymentTargets: .macOS("13.0"),
            sources: ["Sources/iDocs/Main.swift"],
            dependencies: [
                .target(name: "iDocsApp"),
                .target(name: "iDocsAdapter")
            ],
            settings: .settings(
                base: [
                    "PRODUCT_NAME": "idocs",
                    "LD_RUNPATH_SEARCH_PATHS": [
                        "$(inherited)",
                        "@executable_path",
                        "@loader_path",
                        "@executable_path/Frameworks"
                    ]
                ]
            )
        ),
        .target(
            name: "iDocsTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.snow.idocsTests",
            deploymentTargets: .macOS("14.0"),
            sources: ["Tests/iDocsTests/**"],
            dependencies: [
                .target(name: "iDocsKit"),
                .target(name: "iDocsApp"),
                .target(name: "iDocsAdapter")
            ]
        ),
        .target(
            name: "iDocsAdapterTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.snow.idocsAdapterTests",
            deploymentTargets: .macOS("14.0"),
            sources: ["Tests/iDocsAdapterTests/**"],
            dependencies: [
                .target(name: "iDocsAdapter")
            ]
        )
    ]
)
