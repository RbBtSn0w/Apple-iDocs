# Acceptance Traceability Matrix

This matrix maps feature requirements and success criteria to automated validation points.

| ID | Validation Focus | Automated Checks |
|---|---|---|
| FR-001 | Stable CLI command contract (`idocs`) | `Tests/iDocsTests/CLICommandTests.swift` (`contractDocsContainCommands`, `searchDelegatesToMockAdapter`, `fetchSourceMarker`, `listTechnologiesAndFilter`) |
| FR-002 | Capability equivalence preserved in CLI | `scripts/arch-gate.sh`, `Tests/iDocsTests/CLICommandTests.swift` |
| FR-003 | Deterministic layered retrieval policy | `Tests/iDocsTests/ToolTests.swift`, `Tests/iDocsTests/FetchDocToolTests.swift` |
| FR-004 | Local Xcode search is functional | `Tests/iDocsTests/XcodeLocalDocsMockTests.swift`, `Tests/iDocsTests/ToolTests.swift` |
| FR-005 | Local Xcode fetch participates in pipeline | `Tests/iDocsTests/FetchDocToolTests.swift` |
| FR-006 | Dual remote sources supported (Apple + sosumi) | `Tests/iDocsTests/ToolTests.swift`, `Tests/iDocsTests/FetchDocToolTests.swift`, `Sources/iDocs/DataSources/SosumiAPI.swift` |
| FR-007 | Apple-first remote fallback to sosumi | `Tests/iDocsTests/ToolTests.swift` (`searchToolFallsBackToSosumi`), `Tests/iDocsTests/FetchDocToolTests.swift` |
| FR-008 | Source-hit visibility (`cache/local/apple/sosumi`) | `Tests/iDocsTests/CLICommandTests.swift`, `Tests/iDocsAdapterTests/DocumentationServiceContractTests.swift`, `scripts/arch-gate.sh` |
| FR-009 | Stable error categories + non-zero failure exits | `Tests/iDocsTests/CLICommandTests.swift` (`standardizedErrorOutput`, `listStandardizedErrorOutput`) |
| FR-010 | README/spec/contracts/help synchronized | `Tests/iDocsTests/CLICommandTests.swift` (`contractDocsContainCommands`), `README.md`, `specs/006-cli-multisource-docs/contracts/cli-interface.md` |
| FR-011 | Automated capability/contract regression checks | `scripts/arch-gate.sh`, `scripts/spec-trace-gate.sh` |
| FR-012 | CLI-only scope (no MCP runtime/transport) | `scripts/arch-gate.sh`, repository-wide MCP removal checks in existing branch history |
| SC-001 | 100% required capabilities have CLI path | `scripts/arch-gate.sh`, `Tests/iDocsTests/CLICommandTests.swift` |
| SC-002 | Local success in controlled tests | `Tests/iDocsTests/XcodeLocalDocsMockTests.swift`, `Tests/iDocsTests/FetchDocToolTests.swift` |
| SC-003 | Apple fail/miss fallback succeeds in tests | `Tests/iDocsTests/ToolTests.swift`, `Tests/iDocsTests/FetchDocToolTests.swift` |
| SC-004 | Source-hit always present on successful search/fetch tests | `Tests/iDocsTests/CLICommandTests.swift`, `Tests/iDocsAdapterTests/DocumentationServiceContractTests.swift` |
| SC-005 | Contract drift detected | `Tests/iDocsTests/CLICommandTests.swift` (`contractDocsContainCommands`), `scripts/spec-trace-gate.sh` |
| SC-006 | Architecture/capability gates pass | `scripts/arch-gate.sh` |
