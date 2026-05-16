# Verification: Search and Fetch Reliability for Mixed Apple Documentation Sources

**Date**: Monday, May 11, 2026  
**Verifier**: `speckit.superb.verify` flow

## Commands

- `tuist test iDocs --inspect-mode local --no-upload --no-selective-testing -- -destination 'platform=macOS,name=My Mac'` — PASS
- `tuist build` — PASS
- `git diff --check` — PASS
- `tuist test iDocs --inspect-mode local --no-upload --no-selective-testing -- -destination 'platform=macOS,name=My Mac' -only-testing:iDocsTests/XcodeLocalDocsMockTests -only-testing:iDocsTests/CLICommandTests/searchOutputIncludesSourceKindAndFetchSupport` — PASS
- `tuist test iDocs --inspect-mode local --no-upload --no-selective-testing -- -destination 'platform=macOS,name=My Mac' -only-testing:iDocsTests/ToolTests` — PASS
- `node scripts/benchmark/run-search-short-circuit-comparison.mjs --run-id run-20260516-search-short-circuit` — PASS
- `swift scripts/benchmark/probe-xcode-doc-cache.swift --query 'SwiftUI NavigationSplitView'` — PASS
- `swift scripts/benchmark/probe-xcode-doc-cache.swift --query 'NSWindow toolbarStyle'` — PASS

## Spec Verification Checklist

- [x] US1: Mixed search results expose source kind, fetchability, and query provenance — verified by `Tests/iDocsTests/ToolTests.swift`::`searchToolClassifiesMixedApplePageFamilies`, `Tests/iDocsTests/CLICommandTests.swift`::`searchOutputIncludesSourceKindAndFetchSupport`
- [x] US2: App Store Connect Help paths fetch or classify unsupported without `NOT_FOUND` — verified by `Tests/iDocsTests/FetchDocToolTests.swift`::`appStoreConnectHelpFetch`, `Tests/iDocsTests/FetchDocToolTests.swift`::`unsupportedApplePageFamily`, `Tests/iDocsTests/CLICommandTests.swift`::`fetchJSONUnsupportedSourceType`
- [x] US3: Fetch output preserves fallback provenance and aggregate failure attempts — verified by `Tests/iDocsTests/FetchDocToolTests.swift`::`fetchFallbackProvenance`, `Tests/iDocsTests/FetchDocToolTests.swift`::`aggregateFetchFailureIncludesSourceAttempts`, `Tests/iDocsTests/CLICommandTests.swift`::`fetchJSONOutputIncludesDiagnostics`
- [x] US4: Missing local documentation cache is reported as remote-only degradation while search continues — verified by `Tests/iDocsTests/UsageLoggingTests.swift`::`searchDocsToolReportsMissingLocalDocsAsDegradation`
- [x] US5: Broad query fallback preserves original and derived query attempts — verified by `Tests/iDocsTests/ToolTests.swift`::`searchToolPreservesBroadQueryFallbackAttempt`
- [x] FR-001: Search classifies each result by source kind — verified by `searchToolClassifiesMixedApplePageFamilies`
- [x] FR-002: Search indicates fetchability — verified by `searchToolClassifiesMixedApplePageFamilies`, `searchOutputIncludesSourceKindAndFetchSupport`
- [x] FR-003: Search preserves source provenance — verified by `SearchDocsTool falls back to sosumi when apple remote misses`, `searchOutputIncludesSourceKindAndFetchSupport`
- [x] FR-004: Search reports missing local Xcode docs as degradation — verified by `searchDocsToolReportsMissingLocalDocsAsDegradation`
- [x] FR-005: Missing local docs diagnostics are actionable and machine-readable — verified by `searchDocsToolReportsMissingLocalDocsAsDegradation`
- [x] FR-006: Broad natural-language query fallback preserves query attempts — verified by `searchToolPreservesBroadQueryFallbackAttempt`
- [x] FR-007: Fetch preserves ordered source-attempt provenance — verified by `fetchFallbackProvenance`, `fetchJSONOutputIncludesDiagnostics`
- [x] FR-008: Apple remote decode failure is distinct from other failures — verified by `fetchFallbackProvenance`, `aggregateFetchFailureIncludesSourceAttempts`
- [x] FR-009: Fetch diagnostics include sanitized status metadata — verified by `fetchJSONOutputIncludesDiagnostics`, `aggregateFetchFailureIncludesSourceAttempts`
- [x] FR-010: Help fetch covers upload-builds and testflight-overview or explicit non-`NOT_FOUND` classification — verified by `appStoreConnectHelpFetch`
- [x] FR-011: Help fetch includes title, headings, body, and source URL — verified by `appStoreConnectHelpFetch`
- [x] FR-012: Unsupported video/news/App Store Connect pages avoid `NOT_FOUND` — verified by `unsupportedApplePageFamily`, `fetchJSONUnsupportedSourceType`
- [x] FR-013: Aggregate failures list ordered source attempts — verified by `aggregateFetchFailureIncludesSourceAttempts`
- [x] FR-014: CLI-first `search -> fetch` evidence contract remains intact — verified by `contractDocsContainCommands`, existing `CLI Command Tests`, and unchanged command set
- [x] FR-015: Existing `/documentation/...` flows remain compatible — verified by existing `SearchDocsTool handles basic query`, `FetchDocTool fetches from remote API when cache and local miss`, and full suite pass
- [x] FR-016: Issue #8 observed commands are covered — verified by `searchToolClassifiesMixedApplePageFamilies`, `appStoreConnectHelpFetch`, `fetchFallbackProvenance`, `unsupportedApplePageFamily`, `aggregateFetchFailureIncludesSourceAttempts`
- [x] FR-017: App Store Connect API overview has improved diagnostics instead of generic failure — verified by `unsupportedApplePageFamily` for `/app-store-connect/api`
- [x] Addendum: Composite module hints no longer short-circuit symbol/member evidence — verified by `Tests/iDocsTests/XcodeLocalDocsMockTests.swift`::`testCompositeQueryPrefersSymbolPathBeforeModuleHintFallback`, `Tests/iDocsTests/ToolTests.swift`::`searchToolContinuesRemoteAfterLocalModuleFallback`, and `Tests/iDocsTests/CLICommandTests.swift`::`searchOutputIncludesSourceKindAndFetchSupport`
- [x] Addendum: Exact module lookup remains intact — verified by `Tests/iDocsTests/XcodeLocalDocsMockTests.swift`::`testModuleQueryUsesDocumentationRootFastPath` and `run-20260516-search-short-circuit` control query `SwiftUI`
- [x] Addendum: Competitor one-to-one search comparison completed — verified by `specs/008-mcp-service-benchmark/artifacts/results/run-20260516-search-short-circuit/report.md`
- [x] Addendum: Local Xcode cache limitation diagnosed — verified by `idocs-local-cache-probe-swiftui-navigation.json` and `idocs-local-cache-probe-nswindow-toolbarstyle.json` under the same run artifact directory

## Result

Spec coverage: 22/22 original checked items plus 4/4 short-circuit addendum items verified.
