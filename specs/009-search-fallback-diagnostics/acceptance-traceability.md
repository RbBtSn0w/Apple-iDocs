# Acceptance Traceability: search-fallback-diagnostics

| ID | Requirement | Automated check |
|----|-------------|-----------------|
| FR-001 | Detect when local Xcode DocumentationCache is unavailable. | `Tests/iDocsTests/UsageLoggingTests.swift`; `Tests/iDocsTests/ToolTests.swift` |
| FR-002 | Attempt remote lookup when local cache is unavailable. | `Tests/iDocsTests/ToolTests.swift`; `Tests/iDocsTests/UsageLoggingTests.swift` |
| FR-003 | Differentiate remote network/permission failure from successful zero-result lookup. | `Tests/iDocsTests/UsageLoggingTests.swift`; `Tests/iDocsTests/CLICommandTests.swift` |
| FR-004 | Output actionable diagnostic messages for network/permission failure. | `Tests/iDocsTests/UsageLoggingTests.swift`; `Tests/iDocsTests/CLICommandTests.swift` |
| FR-005 | Route exact API and HIG terminology to official Apple Developer documentation pages during remote fallback. | `Tests/iDocsTests/ToolTests.swift` |
| FR-006 | Maintain a CLI-first interface without graphical interaction or browser launch. | `Tests/iDocsTests/CLICommandTests.swift`; `scripts/arch-gate.sh` |
| SC-001 | Return correct links for NavigationSplitView, inspectorColumnWidth, and Split views when local cache is missing and network is available. | `Tests/iDocsTests/ToolTests.swift` |
| SC-002 | Output network/permission diagnostics when local cache and network are unavailable. | `Tests/iDocsTests/UsageLoggingTests.swift`; `Tests/iDocsTests/CLICommandTests.swift` |
| SC-003 | Parsable CLI output distinguishes no results from network errors. | `Tests/iDocsTests/CLICommandTests.swift` |
