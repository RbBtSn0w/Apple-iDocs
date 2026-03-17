# Tasks: Three-Layer Architecture Refactoring

## Phase 0: Setup
- [x] T001 Define `iDocsKit`, `iDocsAdapter`, and `iDocs` targets with correct dependencies in `Project.swift`
- [x] T002 Implement automated Gate checks (SC-005..SC-009) as a script (e.g., `scripts/arch-gate.sh`) and wire it into CI if available (e.g., `.github/workflows/dependency-gate.yml`)
- [x] T003 Remove MCP service targets, dependencies, and runtime code from the project (CLI + future App only)

## Phase 1: Foundational
- [x] T004 [P] Implement `DocumentationConfig` model in `Sources/iDocsAdapter/Models/DocumentationConfig.swift`
- [x] T005 [P] Implement `DocumentationError` enum in `Sources/iDocsAdapter/Models/DocumentationError.swift`
- [x] T006 [P] Implement core entities (`DocumentationContent`, `SearchResult`, `Technology`) in `Sources/iDocsAdapter/Models/CoreEntities.swift`
- [x] T007 Implement `DocumentationService` protocol in `Sources/iDocsAdapter/Protocols/DocumentationService.swift`
- [x] T008 Implement `DocumentationLogger` protocol in the Common layer (e.g., `Sources/iDocsKit/Utils/DocumentationLogger.swift`) and re-export or adapt it for Application layers
- [x] T009 Implement `coreVersion` (SemVer) + parsing helpers in `Sources/iDocsKit/Utils/Version.swift`
- [x] T023 [Test-First] Add `iDocsAdapterTests` target and write adapter contract tests (async API shape, error mapping, config injection)
- [x] T024 [Test-First] Add unit tests for version handshake and SemVer major-compatibility checks

## Phase 2: [US1] Unified CLI Access
**Goal:** CLI acts as a thin wrapper around a stable core service via Adapter.
**Independent Test Criteria:** Run `iDocs search "SwiftUI"`; CLI delegates request to Adapter layer and handles standard errors elegantly.

- [x] T010 [US1] Remove CLI and ArgumentParser framework dependencies from `Sources/iDocsKit/`
- [x] T011 [US1] Implement `DefaultDocumentationAdapter` conforming to `DocumentationService` in `Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift`
- [x] T012 [US1] Implement CLI bootstrap and adapter/config injection via `CLIEnvironment` in `Sources/iDocs/Main.swift` and `Sources/iDocs/Commands/`
- [x] T013 [P] [US1] Migrate `search`, `fetch`, `list` CLI commands to `AsyncParsableCommand` and Adapter API in `Sources/iDocs/Commands/`
- [x] T014 [P] [US1] Implement user-friendly `DocumentationError` handling and output mapping in `Sources/iDocs/Commands/`
- [x] T015 [US1] Enforce runtime version compatibility in the Adapter init/startup (FR-014), fail fast on incompatible major versions, and surface a clear error to CLI/App
- [x] T025 [Test-First] Add CLI tests that use `MockDocumentationAdapter` to validate: adapter-only access, standardized error output, and version mismatch reporting

## Phase 3: [US2] Future App Integration Readiness
**Goal:** Architect system to allow native App UI using exactly the same core logic.
**Independent Test Criteria:** Verify `iDocsKit` respects sandbox constraints by ensuring cache paths are explicitly injected and async/await is exclusively used.

- [x] T016 [P] [US2] Ensure all cache paths come from injected `DocumentationConfig` (no global writable paths by default) in `Sources/iDocsKit/Cache/`
- [x] T017 [P] [US2] Audit Common-layer APIs for platform types (AppKit/UIKit paths, NSView/UIView, etc.) and enforce cross-platform-safe types in public Adapter/Common interfaces
- [x] T018 [US2] Update Tuist configuration so Common/Adapter can be built as `.framework` / `.xcframework` for App targets; add a packaging/build task (not only `Project.swift`)

## Phase 4: [US3] Mock Adapter for Isolated Testing
**Goal:** Swap real Common layer with Mock implementation for testing Application layers without network or cache.
**Independent Test Criteria:** CLI unit tests must all pass using `MockDocumentationAdapter`.

- [x] T019 [US3] Implement `MockDocumentationAdapter` or `InMemoryAdapter` in `Sources/iDocsAdapter/Adapters/`
- [x] T020 [US3] Update CLI test suite to use the mock adapter and add tests for: error mapping, version mismatch failure, and config injection in `Tests/`

## Phase 5: Polish & Cross-Cutting Concerns
- [x] T021 Implement optional cross-process file lock (e.g., `Darwin.flock`) only for explicit shared-cache setups (e.g., App Group directory) in `Sources/iDocsKit/Cache/`, gated by `DocumentationConfig.enableFileLocking`
- [x] T022 Document Gate checks and how to run them locally (e.g., `scripts/arch-gate.sh`) in `specs/005-three-layer-architecture/quickstart.md`

## Dependencies
- Phase 1 (Foundational) depends on Phase 0 (Setup).
- Phase 2 (US1) depends on Phase 1.
- Phase 3 (US2) can run in parallel with Phase 2, but depends on Phase 1.
- Phase 4 (US3) depends on Phase 1 and the Phase 2 CLI command structure.
- Phase 5 (Polish) depends on completion of Phases 2-4.

## Parallel Execution Examples
- **US1 & US2:** `DefaultDocumentationAdapter` (T011) can be built in parallel with cache-path injection work (T016) once foundational models are in place.
- **Within phase 2:** Models (T004, T005, T006) can be implemented completely independently by different developers.

## Implementation Strategy
Start with the MVP (Phases 0-2) to establish the boundary and CLI entry point using the Adapter. Then progress to App readiness, mock-based testing, and final Gate enforcement.
