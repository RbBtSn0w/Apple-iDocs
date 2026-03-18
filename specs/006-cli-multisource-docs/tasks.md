# Tasks: iDocs CLI Capability Unification and Multi-Source Retrieval

**Input**: Design documents from `/specs/006-cli-multisource-docs/`  
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: This feature requires tests for retrieval-chain behavior, fallback behavior, source observability, and contract stability.

**Organization**: Tasks are grouped by user story so each story can be implemented and validated independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no direct dependency)
- **[Story]**: User story label (`US1`, `US2`, `US3`, `US4`)

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Create feature docs skeleton consistency check for `specs/006-cli-multisource-docs/` artifacts
- [x] T002 [P] Add/update test fixtures for Apple and sosumi search/fetch payloads in `Tests/iDocsTests/TestSupport/MockPayloads.swift`
- [x] T003 [P] Add/update mock session helpers for multi-source endpoint stubbing in `Tests/iDocsTests/Mocks/MockNetworkSession.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T004 Introduce source model in core result types for search/fetch outputs in `Sources/iDocs/Rendering/DocCTypes.swift`
- [x] T005 Introduce adapter-facing source field in search/domain models in `Sources/iDocsAdapter/Models/CoreEntities.swift`
- [x] T006 Add URL builders for sosumi search/fetch endpoints in `Sources/iDocs/Utils/URLHelpers.swift`
- [x] T007 Implement sosumi remote datasource client for search/fetch in `Sources/iDocs/DataSources/SosumiAPI.swift`
- [x] T008 [P] Add unit tests for URL/source-model correctness in `Tests/iDocsTests/URLHelpersTests.swift` and `Tests/iDocsTests/IntegrationTests/AppleAPITests.swift`

**Checkpoint**: Core types and datasource primitives are ready; user stories can proceed.

---

## Phase 3: User Story 1 - Unified CLI Contract (Priority: P1) 🎯 MVP

**Goal**: Stabilize CLI search/fetch contract while keeping standardized errors and predictable outputs.

**Independent Test**: `idocs search`/`idocs fetch` produce stable output and errors via adapter-only access.

### Tests for User Story 1

- [x] T009 [P] [US1] Add CLI contract tests for stable search/fetch output shape in `Tests/iDocsTests/CLICommandTests.swift`
- [x] T010 [P] [US1] Add adapter mapping tests for source propagation in `Tests/iDocsAdapterTests/DocumentationServiceContractTests.swift`

### Implementation for User Story 1

- [x] T011 [US1] Propagate source metadata from iDocsKit to adapter search results in `Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift`
- [x] T012 [US1] Include fetch source metadata in adapter response metadata contract in `Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift`
- [x] T013 [US1] Update CLI rendering to expose source-hit in search/fetch output in `Sources/iDocs/Commands/CLIExecutor.swift`
- [x] T014 [US1] Preserve error category and exit-code compatibility for new source paths in `Sources/iDocs/Commands/CLIErrorPresenter.swift`

**Checkpoint**: CLI contract works with source visibility and stable errors.

---

## Phase 4: User Story 2 - Complete Local Xcode Retrieval (Priority: P1)

**Goal**: Make local Xcode search/fetch fully functional as a real retrieval layer.

**Independent Test**: with local fixtures, search/fetch succeed without remote dependency.

### Tests for User Story 2

- [x] T015 [P] [US2] Add local-search hit/miss tests in `Tests/iDocsTests/XcodeLocalDocsMockTests.swift`
- [x] T016 [P] [US2] Add local-first chain tests for search tool in `Tests/iDocsTests/ToolTests.swift`
- [x] T017 [P] [US2] Extend fetch local-hit tests to assert source metadata in `Tests/iDocsTests/FetchDocToolTests.swift`

### Implementation for User Story 2

- [x] T018 [US2] Replace placeholder local search with file-based deterministic search in `Sources/iDocs/DataSources/XcodeLocalDocs.swift`
- [x] T019 [US2] Implement optional Spotlight provider integration path (non-blocking fallback) in `Sources/iDocs/Utils/SpotlightSearchProvider.swift`
- [x] T020 [US2] Ensure search tool records local source hit and cache source hit in `Sources/iDocs/Tools/SearchDocsTool.swift`
- [x] T021 [US2] Ensure fetch tool records cache/local source hit in `Sources/iDocs/Tools/FetchDocTool.swift`

**Checkpoint**: Local layer is functional and observable.

---

## Phase 5: User Story 3 - Dual Remote Fallback Resilience (Priority: P1)

**Goal**: Add deterministic `apple -> sosumi` fallback for search/fetch.

**Independent Test**: simulate Apple miss/failure and verify sosumi fallback succeeds.

### Tests for User Story 3

- [x] T022 [P] [US3] Add search fallback tests (apple fail/miss -> sosumi hit) in `Tests/iDocsTests/ToolTests.swift`
- [x] T023 [P] [US3] Add fetch fallback tests (apple fail/miss -> sosumi hit) in `Tests/iDocsTests/FetchDocToolTests.swift`
- [x] T024 [P] [US3] Add integration-gated remote fallback diagnostics test in `Tests/iDocsTests/IntegrationTests/NetworkToolTests.swift`

### Implementation for User Story 3

- [x] T025 [US3] Update search tool chain to `local -> apple -> sosumi` with terminal error mapping in `Sources/iDocs/Tools/SearchDocsTool.swift`
- [x] T026 [US3] Update fetch tool chain to `cache -> local -> apple -> sosumi` with source tagging in `Sources/iDocs/Tools/FetchDocTool.swift`
- [x] T027 [US3] Adjust Apple API failure behavior to support controlled fallback triggers in `Sources/iDocs/DataSources/AppleJSONAPI.swift`

**Checkpoint**: Dual remote fallback is deterministic and testable.

---

## Phase 6: User Story 4 - Source Visibility and Anti-Regression Gates (Priority: P2)

**Goal**: Prevent capability/contract drift by automated checks and synchronized docs.

**Independent Test**: gate scripts detect contract/capability regressions and docs stay aligned.

### Tests for User Story 4

- [x] T028 [P] [US4] Add CLI tests asserting source-hit visibility in output for search/fetch in `Tests/iDocsTests/CLICommandTests.swift`
- [x] T029 [P] [US4] Add contract drift tests for command/help docs alignment in `Tests/iDocsTests/CLICommandTests.swift`

### Implementation for User Story 4

- [x] T030 [US4] Extend architecture gate with capability/contract checks in `scripts/arch-gate.sh`
- [x] T031 [US4] Update CLI contract docs for this feature in `specs/006-cli-multisource-docs/contracts/cli-interface.md`
- [x] T032 [US4] Update project README usage and source behavior notes in `README.md`
- [x] T033 [US4] Update feature quickstart verification commands and expected outputs in `specs/006-cli-multisource-docs/quickstart.md`

**Checkpoint**: Source observability and anti-regression guardrails are in place.

---

## Phase 7: Polish & Cross-Cutting

- [x] T034 [P] Run full feature validation workflow from quickstart and capture results in `specs/006-cli-multisource-docs/quickstart.md`
- [x] T035 [P] Run architecture gate and fix any final drift in `scripts/arch-gate.sh`
- [x] T036 Final pass on spec/plan/research/data-model/contracts/tasks consistency in `specs/006-cli-multisource-docs/`

---

## Dependencies & Execution Order

### Phase Dependencies

- Phase 1 → no dependencies
- Phase 2 → depends on Phase 1
- Phase 3/4/5/6 → depend on Phase 2
- Phase 7 → depends on completion of targeted user stories

### User Story Dependencies

- **US1 (P1)**: starts after foundational phase
- **US2 (P1)**: starts after foundational phase
- **US3 (P1)**: depends on foundational phase and benefits from US2 local-layer completion
- **US4 (P2)**: depends on US1/US3 outputs for stable contract + source visibility

### Parallel Opportunities

- T002/T003 can run in parallel
- T004/T005/T006 with T008 can be parallelized carefully
- Test tasks marked `[P]` per story can be run in parallel
- US1 and US2 can proceed concurrently after Phase 2

---

## Implementation Strategy

### MVP First

1. Complete Phases 1-2
2. Deliver US1 + US2 (stable contract + functional local layer)
3. Validate MVP independently

### Reliability Increment

4. Deliver US3 for deterministic dual-remote fallback
5. Deliver US4 gate/docs hardening
6. Run Phase 7 final validation
