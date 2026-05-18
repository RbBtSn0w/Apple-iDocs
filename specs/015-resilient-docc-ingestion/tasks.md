# Tasks: Resilient DocC Ingestion

**Input**: Design documents from `specs/015-resilient-docc-ingestion/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are REQUIRED because this changes runtime Apple remote ingestion, fetch fallback decisions, and diagnostics.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm active feature context and current failure boundary.

- [X] T001 Verify active feature pointer and checklist status in `.specify/feature.json` and `specs/015-resilient-docc-ingestion/checklists/requirements.md`
- [X] T002 Inspect current Apple remote decode, fetch fallback, renderer, and DocC model boundaries in `Sources/iDocsKit/DataSources/AppleJSONAPI.swift`, `Sources/iDocsKit/Tools/FetchDocTool.swift`, `Sources/iDocsKit/Rendering/DocCTypes.swift`, and `Sources/iDocsKit/Rendering/DocCRenderer.swift`
- [X] T003 Run baseline full tests with `./scripts/tuist-silent.sh test`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add shared typed loose JSON and fixture support before user-story implementation.

- [X] T004 [P] Add tolerant Apple DocC fixture helpers in `Tests/iDocsTests/TestSupport/MockPayloads.swift`
- [X] T005 [P] Add RED `JSONValue` decoding tests in `Tests/iDocsTests/AppleDocCIngestionTests.swift`
- [X] T006 Add `JSONValue` typed loose JSON support in `Sources/iDocsKit/Rendering/AppleDocCIngestion.swift`

**Checkpoint**: Tolerant ingestion primitives and fixtures are ready.

---

## Phase 3: User Story 1 - Fetch Apple Documentation Despite Non-Critical Schema Drift (Priority: P1) 🎯 MVP

**Goal**: Apple remote payloads with required evidence and unknown non-critical nodes return Apple-sourced markdown and do not fall back.

**Independent Test**: Simulate cache/local misses plus an Apple remote payload containing known content and unknown nodes; verify selected source, source attempts, markdown, and partial diagnostics.

### Tests for User Story 1 ⚠️

- [X] T007 [US1] Add RED normalizer test for partial Apple payload success in `Tests/iDocsTests/AppleDocCIngestionTests.swift`
- [X] T008 [US1] Add RED fetch test for partial Apple payload stopping before sosumi in `Tests/iDocsTests/FetchDocToolTests.swift`

### Implementation for User Story 1

- [X] T009 [US1] Implement tolerant Apple payload normalization into stable `DocCContent` in `Sources/iDocsKit/Rendering/AppleDocCIngestion.swift`
- [X] T010 [US1] Wire Apple remote fetch to use tolerant ingestion before failing in `Sources/iDocsKit/DataSources/AppleJSONAPI.swift`
- [X] T011 [US1] Wire partial diagnostics into Apple fetch source attempts in `Sources/iDocsKit/Tools/FetchDocTool.swift`
- [X] T012 [US1] Run full tests with `./scripts/tuist-silent.sh test`

**Checkpoint**: User Story 1 is independently functional.

---

## Phase 4: User Story 2 - Preserve Stable Public Output and Cache Shape (Priority: P2)

**Goal**: Normalized tolerant Apple content encodes as stable `DocCContent` without raw JSON leakage.

**Independent Test**: Normalize an Apple payload with unknown shapes, encode the result, and assert stable fields only.

### Tests for User Story 2 ⚠️

- [X] T013 [US2] Add RED stable encode test for normalized Apple content in `Tests/iDocsTests/AppleDocCIngestionTests.swift`

### Implementation for User Story 2

- [X] T014 [US2] Ensure normalized content uses existing stable `DocCContent` encode path in `Sources/iDocsKit/Rendering/AppleDocCIngestion.swift` and `Sources/iDocsKit/Rendering/DocCTypes.swift`
- [X] T015 [US2] Run full tests with `./scripts/tuist-silent.sh test`

**Checkpoint**: Public/cache output remains stable.

---

## Phase 5: User Story 3 - Fail Clearly When Required Core Evidence Is Missing (Priority: P3)

**Goal**: Required-core failures still fall back with path-aware diagnostics.

**Independent Test**: Simulate Apple remote JSON missing required core evidence and verify fallback plus path-aware Apple failure reason.

### Tests for User Story 3 ⚠️

- [X] T016 [US3] Add RED normalizer failure test for missing required core evidence in `Tests/iDocsTests/AppleDocCIngestionTests.swift`
- [X] T017 [US3] Add RED fetch fallback test for path-aware Apple failure diagnostics in `Tests/iDocsTests/FetchDocToolTests.swift`

### Implementation for User Story 3

- [X] T018 [US3] Implement required-core validation and failure diagnostics in `Sources/iDocsKit/Rendering/AppleDocCIngestion.swift`
- [X] T019 [US3] Preserve existing fallback behavior for required-core failures in `Sources/iDocsKit/Tools/FetchDocTool.swift`
- [X] T020 [US3] Run full tests with `./scripts/tuist-silent.sh test`

**Checkpoint**: Invalid Apple payloads remain diagnosable and fallback-compatible.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Validate full feature and synchronize status.

- [X] T021 Run optional temporary-cache live fetch smoke from `specs/015-resilient-docc-ingestion/quickstart.md`
- [X] T022 Run full verification suite with `./scripts/tuist-silent.sh test`
- [X] T023 Update `specs/015-resilient-docc-ingestion/tasks.md` so all completed tasks are checked

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies
- **Foundational (Phase 2)**: Depends on Setup completion
- **User Story 1 (Phase 3)**: Depends on `JSONValue` and fixtures
- **User Story 2 (Phase 4)**: Depends on User Story 1 normalization
- **User Story 3 (Phase 5)**: Depends on User Story 1 diagnostics/fetch wiring
- **Polish (Phase 6)**: Depends on all user stories

### Parallel Opportunities

- T004 and T005 touch different files and can run in parallel.
- T007 and T008 touch different test files and can be authored before production changes.
- User Story 2 and User Story 3 tests can be written in parallel after User Story 1 normalizer shape is visible.

## Implementation Strategy

1. Confirm baseline.
2. Add RED tests for typed loose JSON and tolerant Apple payload success.
3. Implement minimal normalizer and fetch wiring.
4. Add stable encode and required-core failure tests.
5. Run full suite, optional live smoke, then `speckit.superb.verify` and finish.
