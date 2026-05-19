# Tasks: Robust DocC Identifier Fetch

**Input**: Design documents from `specs/014-fix-docc-identifier/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are REQUIRED because this changes runtime DocC decoding and fetch fallback behavior.

**Organization**: Tasks are grouped by user story so each story can be implemented and tested independently.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm the current feature context and affected files.

- [X] T001 Verify active feature pointer and checklist status in `.specify/feature.json` and `specs/014-fix-docc-identifier/checklists/requirements.md`
- [X] T002 Inspect current DocC content decoding and fetch fallback behavior in `Sources/iDocsKit/Rendering/DocCTypes.swift` and `Sources/iDocsKit/Tools/FetchDocTool.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish test fixture support used by the user-story tests.

- [X] T003 [P] Add object identifier DocC fixture helper in `Tests/iDocsTests/TestSupport/MockPayloads.swift`
- [X] T004 [P] Add invalid object identifier DocC fixture helper in `Tests/iDocsTests/TestSupport/MockPayloads.swift`

**Checkpoint**: Fixture helpers are ready for RED tests.

---

## Phase 3: User Story 1 - Fetch Current Apple DocC Content (Priority: P1) 🎯 MVP

**Goal**: Apple remote DocC JSON with object-shaped identifier succeeds from Apple and does not fall through to sosumi.

**Independent Test**: Simulate cache/local misses and Apple remote object identifier content, then verify selected source and source attempts.

### Tests for User Story 1 ⚠️

- [X] T005 [US1] Add RED fetch test for Apple object identifier success and source attempts in `Tests/iDocsTests/FetchDocToolTests.swift`

### Implementation for User Story 1

- [X] T006 [US1] Add typed object identifier decoding support in `Sources/iDocsKit/Rendering/DocCTypes.swift`
- [X] T007 [US1] Run focused fetch test for object identifier behavior through `./scripts/tuist-silent.sh test`

**Checkpoint**: User Story 1 is fully functional and independently testable.

---

## Phase 4: User Story 2 - Preserve Existing Identifier Compatibility (Priority: P2)

**Goal**: Existing string identifier content and encoded cache/test-helper output remain stable.

**Independent Test**: Decode string identifier content and encode `DocCContent`; confirm both use the string shape.

### Tests for User Story 2 ⚠️

- [X] T008 [US2] Add RED DocCContent decode/encode compatibility tests in `Tests/iDocsTests/DocCTypesTests.swift`

### Implementation for User Story 2

- [X] T009 [US2] Implement custom `DocCContent.encode(to:)` to emit string identifier in `Sources/iDocsKit/Rendering/DocCTypes.swift`
- [X] T010 [US2] Run focused DocC type tests through `./scripts/tuist-silent.sh test`

**Checkpoint**: Existing string identifier and cache output compatibility are preserved.

---

## Phase 5: User Story 3 - Keep Invalid Remote Content Diagnosable (Priority: P3)

**Goal**: Malformed object identifiers still record `remote_decode_failed` and preserve fallback behavior.

**Independent Test**: Simulate Apple content with object identifier missing URL and sosumi fallback, then verify Apple diagnostic and fallback source.

### Tests for User Story 3 ⚠️

- [X] T011 [US3] Add RED fetch test for object identifier missing URL fallback diagnostics in `Tests/iDocsTests/FetchDocToolTests.swift`

### Implementation for User Story 3

- [X] T012 [US3] Ensure missing object identifier URL throws a standard decoding key-not-found error in `Sources/iDocsKit/Rendering/DocCTypes.swift`
- [X] T013 [US3] Run focused fetch fallback diagnostics test through `./scripts/tuist-silent.sh test`

**Checkpoint**: Invalid Apple payloads remain diagnosable and fallback-compatible.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Validate the full feature and synchronize status.

- [X] T014 Run full test suite with `./scripts/tuist-silent.sh test`
- [X] T015 [P] Optionally run live fetch smoke with `./scripts/tuist-silent.sh run idocs fetch /documentation/swiftui/navigationsplitview --json`
- [X] T016 Update `specs/014-fix-docc-identifier/tasks.md` so all completed tasks are checked

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies
- **Foundational (Phase 2)**: Depends on Setup completion
- **User Story 1 (Phase 3)**: Depends on fixture helpers
- **User Story 2 (Phase 4)**: Depends on shared `DocCContent` compatibility implementation from US1
- **User Story 3 (Phase 5)**: Depends on shared `DocCContent` compatibility implementation from US1
- **Polish (Phase 6)**: Depends on all user stories

### User Story Dependencies

- **User Story 1 (P1)**: MVP; must land first because it introduces object identifier decoding.
- **User Story 2 (P2)**: Verifies backward compatibility after the decoder changes.
- **User Story 3 (P3)**: Verifies invalid object shape still fails cleanly.

### Parallel Opportunities

- T003 and T004 touch the same file and should be coordinated in one edit, but their fixture definitions are independent.
- T015 can be skipped when network smoke is inappropriate; full local tests remain mandatory.

## Implementation Strategy

1. Complete setup and fixture helpers.
2. Add RED tests before changing production decoding.
3. Implement custom decode/encode in the content model.
4. Run focused tests, then the full test suite.
5. Run `speckit.superb.verify` before finish/PR.
