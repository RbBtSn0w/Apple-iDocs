# Tasks: Search and Fetch Reliability for Mixed Apple Documentation Sources

**Input**: Design documents from `specs/011-search-fetch-reliability/`  
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/cli-output.md, quickstart.md

**Tests**: Required by spec and Constitution. Write/adjust tests before implementation.

**Organization**: Tasks are grouped by user story to enable independently testable increments.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm current feature context and generated planning artifacts.

- [x] T001 Verify `.specify/feature.json`, `AGENTS.md`, and `specs/011-search-fetch-reliability/plan.md` point to the 011 feature.
- [x] T002 [P] Confirm existing Swift/Tuist source boundaries in `Sources/iDocsKit`, `Sources/iDocsAdapter`, `Sources/iDocsApp`, and matching tests under `Tests/`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared typed metadata and diagnostics needed by every user story.

- [x] T003 Add failing tests for source-kind and fetch-capability classification in `Tests/iDocsTests/ToolTests.swift`.
- [x] T004 Add typed source kind, fetch capability, query attempt, and fetch attempt models in `Sources/iDocsKit/Rendering/DocCTypes.swift` and `Sources/iDocsKit/Utils/DocumentationUsageRecorder.swift`.
- [x] T005 Update adapter-facing entities for source kind, fetchability, query attempt, and fetch diagnostics in `Sources/iDocsAdapter/Models/CoreEntities.swift`.
- [x] T006 Update CLI JSON payload models for new search and fetch fields in `Sources/iDocsApp/Commands/CLIOutputModels.swift`.

**Checkpoint**: Shared model layer compiles and can express every 011 diagnostic contract.

---

## Phase 3: User Story 1 - Understand Mixed Search Results Before Fetching (Priority: P1) MVP

**Goal**: Search results expose source kind, fetchability, and query provenance.

**Independent Test**: A mixed mocked search response returns documentation, Help, video, news, and marketing paths with stable classification and fetchability.

### Tests for User Story 1

- [x] T007 [P] [US1] Add failing mixed-result classification tests in `Tests/iDocsTests/ToolTests.swift`.
- [x] T008 [P] [US1] Add failing CLI JSON/text output tests for search result metadata in `Tests/iDocsTests/CLICommandTests.swift`.

### Implementation for User Story 1

- [x] T009 [US1] Implement path-based source-kind and fetchability classification in `Sources/iDocsKit/Tools/SearchDocsTool.swift` and related model initializers.
- [x] T010 [US1] Map search metadata through `Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift` and `Sources/iDocsAdapter/Adapters/MockDocumentationAdapter.swift`.
- [x] T011 [US1] Render search metadata in text and JSON output from `Sources/iDocsApp/Commands/CLIExecutor.swift`.

**Checkpoint**: User Story 1 is fully testable without fetch changes.

---

## Phase 4: User Story 2 - Fetch App Store Connect Help Evidence Reliably (Priority: P1)

**Goal**: App Store Connect Help paths fetch readable content or return explicit unsupported/fetch-failed diagnostics instead of misleading `NOT_FOUND`.

**Independent Test**: Mocked Help HTML for `/help/app-store-connect/manage-builds/upload-builds` returns markdown title/body/source URL; unsupported Apple paths return unsupported-source classification.

### Tests for User Story 2

- [x] T012 [P] [US2] Add failing Help fetch and unsupported-source tests in `Tests/iDocsTests/FetchDocToolTests.swift`.
- [x] T013 [P] [US2] Add failing CLI fetch error classification tests in `Tests/iDocsTests/CLICommandTests.swift`.

### Implementation for User Story 2

- [x] T014 [US2] Add App Store Connect Help URL construction and HTML extraction support in `Sources/iDocsKit/Utils/URLHelpers.swift` and `Sources/iDocsKit/DataSources/AppleHelpAPI.swift`.
- [x] T015 [US2] Integrate Help fetch and unsupported-source classification in `Sources/iDocsKit/Tools/FetchDocTool.swift`.
- [x] T016 [US2] Map unsupported-source errors through `Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift` and `Sources/iDocsApp/Commands/CLIErrorPresenter.swift`.

**Checkpoint**: User Story 2 works independently for Help and unsupported page families.

---

## Phase 5: User Story 3 - Preserve Fallback Provenance for Fetch Results (Priority: P1)

**Goal**: Fetch success and failure expose ordered source-attempt diagnostics.

**Independent Test**: Mocked Apple decode failure followed by sosumi success records both attempts; Apple decode failure followed by sosumi HTTP 500 returns aggregate attempts.

### Tests for User Story 3

- [x] T017 [P] [US3] Add failing fetch provenance tests in `Tests/iDocsTests/FetchDocToolTests.swift`.
- [x] T018 [P] [US3] Add failing CLI JSON fetch diagnostics tests in `Tests/iDocsTests/CLICommandTests.swift`.

### Implementation for User Story 3

- [x] T019 [US3] Record ordered fetch attempts in `Sources/iDocsKit/Tools/FetchDocTool.swift`.
- [x] T020 [US3] Preserve fetch diagnostics through `Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift`.
- [x] T021 [US3] Emit `fetch_diagnostics` for fetch success and failure in `Sources/iDocsApp/Commands/CLIExecutor.swift`.

**Checkpoint**: User Story 3 explains successful fallback and aggregate failures.

---

## Phase 6: User Story 4 - Surface Local Documentation Cache Degradation (Priority: P2)

**Goal**: Missing local Xcode documentation is reported as structured remote-only degradation.

**Independent Test**: A search with a nonexistent local docs cache continues remotely and reports `local_docs_unavailable`.

### Tests for User Story 4

- [x] T022 [P] [US4] Add failing local-cache degradation tests in `Tests/iDocsTests/UsageLoggingTests.swift`.

### Implementation for User Story 4

- [x] T023 [US4] Distinguish missing local documentation from empty local results in `Sources/iDocsKit/DataSources/XcodeLocalDocs.swift` and `Sources/iDocsKit/Tools/SearchDocsTool.swift`.
- [x] T024 [US4] Expose the degradation through adapter and CLI diagnostics in `Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift` and `Sources/iDocsApp/Commands/CLIExecutor.swift`.

**Checkpoint**: User Story 4 is independently verified through detailed search diagnostics.

---

## Phase 7: User Story 5 - Normalize Broad Queries Without Hiding the Original Query (Priority: P3)

**Goal**: Broad fallback search can use a derived keyword query while preserving original query provenance.

**Independent Test**: A broad query with Apple no-results and fallback keyword results records original and derived query attempts.

### Tests for User Story 5

- [x] T025 [P] [US5] Add failing broad-query fallback provenance tests in `Tests/iDocsTests/ToolTests.swift`.

### Implementation for User Story 5

- [x] T026 [US5] Add conservative keyword fallback query generation in `Sources/iDocsKit/Tools/SearchDocsTool.swift`.
- [x] T027 [US5] Preserve query-attempt metadata through search results, adapter mapping, CLI text output, and CLI JSON output.

**Checkpoint**: User Story 5 is verified without replacing or hiding the original query.

---

## Final Phase: Polish & Cross-Cutting Concerns

- [x] T028 Update usage logging tests and structures so diagnostics remain sanitized in `Tests/iDocsTests/UsageLoggingTests.swift` and `Sources/iDocsKit/Utils/DocumentationUsageRecorder.swift`.
- [x] T029 Run quickstart validation scenarios from `specs/011-search-fetch-reliability/quickstart.md` where deterministic mocks or local commands are available.
- [x] T030 Run `tuist test iDocs --inspect-mode local --no-upload --no-selective-testing -- -destination 'platform=macOS,name=My Mac'`.
- [x] T031 Run `git diff --check`.
- [x] T032 Run spec-coverage verification and update status through the verify gate.

---

## Issue Addendum: Module Hint Short-Circuit

**Input**: `issue-reports/2026-05-16-search-module-hint-short-circuit.md`

**Goal**: Composite API-symbol queries must not stop at a framework/module hint when a symbol-level local path can be recovered.

- [x] T033 [P] Add failing local search tests for `SwiftUI NavigationSplitView`, `NavigationSplitView`, and module-hint fallback sequencing in `Tests/iDocsTests/XcodeLocalDocsMockTests.swift`.
- [x] T034 [P] Add failing CLI contract coverage for search result `match_scope` in `Tests/iDocsTests/CLICommandTests.swift`.
- [x] T035 Add typed match-scope metadata through `Sources/iDocsKit/Rendering/DocCTypes.swift`, `Sources/iDocsAdapter/Models/CoreEntities.swift`, and `Sources/iDocsApp/Commands/CLIOutputModels.swift`.
- [x] T036 Change `Sources/iDocsKit/DataSources/XcodeLocalDocs.swift` so exact module queries keep the fast path, composite queries run provider/index path search first, and module hints are returned only as fallback candidates.
- [x] T037 Update `Sources/iDocsKit/Tools/SearchDocsTool.swift`, `Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift`, and `Sources/iDocsApp/Commands/CLIExecutor.swift` to preserve and render `match_scope`.
- [x] T038 Update `specs/011-search-fetch-reliability/contracts/cli-output.md`, `specs/011-search-fetch-reliability/test-intent.md`, and `specs/011-search-fetch-reliability/verification.md` with the addendum evidence.
- [x] T039 Run targeted tests for the short-circuit fix.
- [x] T040 Run full headless test, build, and diff verification.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on setup and blocks all user stories.
- **US1, US2, US3**: P1 stories can proceed after Foundational; implement in listed order because shared CLI payload work benefits later fetch diagnostics.
- **US4**: Depends on search diagnostics from US1.
- **US5**: Depends on query-attempt metadata from US1.
- **Polish**: Depends on selected user stories and all shared diagnostics.

### Parallel Opportunities

- T002 can run independently from T001.
- Test-writing tasks marked `[P]` touch different test cases and can be drafted independently.
- US2 Help fetch implementation and US3 fetch-attempt diagnostics both touch `FetchDocTool.swift`, so implementation must be coordinated sequentially.

## Implementation Strategy

1. Complete setup and foundational model changes.
2. Implement US1 as the MVP because search classification prevents unsupported fetch attempts.
3. Implement US2 and US3 to close the fetch reliability gap.
4. Implement US4 and US5 for diagnostics and recall improvements.
5. Run full verification and finish gates.
