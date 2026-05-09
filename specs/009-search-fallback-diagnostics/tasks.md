---
description: "Task list for search quality and fallback diagnostics implementation"
---

# Tasks: search-fallback-diagnostics

**Input**: Design documents from `/specs/009-search-fallback-diagnostics/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md
**Status**: Implemented and ready for verification.

## Phase 1: Setup And Shared Infrastructure

- [x] T001 Define search diagnostic response models in `Sources/iDocsAdapter/Models/CoreEntities.swift`.
- [x] T002 Extend the adapter search contract with `searchDetailed(query:config:)` in `Sources/iDocsAdapter/Protocols/DocumentationService.swift`.
- [x] T003 Preserve the existing `[SearchResult]` search API through default adapter compatibility in `Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift` and `Sources/iDocsAdapter/Adapters/MockDocumentationAdapter.swift`.

## Phase 2: User Story 1 - Graceful Degradation On Network Failure

**Goal**: Distinguish remote permission/network failures from true no-result search misses and provide actionable diagnostics.

- [x] T004 Record local cache availability and cache miss status in `Sources/iDocsKit/Tools/SearchDocsTool.swift`.
- [x] T005 Classify remote Apple and sosumi fallback failures into diagnostic reasons in `Sources/iDocsKit/Tools/SearchDocsTool.swift`.
- [x] T006 Surface diagnostic stage data in CLI JSON and text output through `Sources/iDocsApp/Commands/CLIOutputModels.swift` and `Sources/iDocsApp/Commands/CLIExecutor.swift`.
- [x] T007 Add regression coverage for permission failure versus remote no-result miss in `Tests/iDocsTests/UsageLoggingTests.swift`.
- [x] T008 Add CLI JSON diagnostics coverage in `Tests/iDocsTests/CLICommandTests.swift`.

## Phase 3: User Story 2 - Accurate Remote Fallback Search

**Goal**: Find or route known official Apple pages for exact API or HIG terms during fallback.

- [x] T009 Add direct Apple Developer route recovery in `Sources/iDocsKit/DataSources/AppleJSONAPI.swift`.
- [x] T010 Cover known API/HIG terms including `NavigationSplitView`, `inspectorColumnWidth`, split views, and sidebars in `Tests/iDocsTests/ToolTests.swift`.
- [x] T011 Verify live CLI fallback output for the known terms in `specs/009-search-fallback-diagnostics/quickstart.md`.

## Phase 4: User Story 3 - Distinguishing True Misses

**Goal**: Reliably report documentation not found versus network error.

- [x] T012 Preserve successful zero-result searches as `exit_category: OK` with `remote_no_results` diagnostics in `Sources/iDocsApp/Commands/CLIExecutor.swift`.
- [x] T013 Add CLI JSON coverage for true remote miss classification in `Tests/iDocsTests/CLICommandTests.swift`.

## Phase 5: Polish And Cross-Cutting Concerns

- [x] T014 Document search fallback diagnostics in `README.md`.
- [x] T015 Replace template plan and quickstart commands with actual Tuist verification commands in `specs/009-search-fallback-diagnostics/plan.md` and `specs/009-search-fallback-diagnostics/quickstart.md`.
- [x] T016 Add requirement-to-test traceability in `specs/009-search-fallback-diagnostics/acceptance-traceability.md`.
- [x] T017 Add an explicit shared `iDocs` scheme in `Project.swift` so `tuist build` and headless `tuist test --inspect-mode local` exercise the CLI and test targets.

## Verification Checklist

- [x] `tuist build`
- [x] `tuist test --inspect-mode local --no-selective-testing -- -destination 'platform=macOS,name=My Mac'`
- [x] `./scripts/arch-gate.sh`
- [x] `git diff --check`
