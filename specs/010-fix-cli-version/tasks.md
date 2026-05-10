# Tasks: CLI Version Support

**Input**: Design documents from `/specs/010-fix-cli-version/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: The examples below include test tasks. Tests are OPTIONAL - only include them if explicitly requested in the feature specification.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: `src/`, `tests/` at repository root
- **Web app**: `backend/src/`, `frontend/src/`
- **Mobile**: `api/src/`, `ios/src/` or `android/src/`
- Paths shown below assume single project - adjust based on plan.md structure

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

*(No setup tasks required for this simple CLI feature)*

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

*(No foundational tasks required for this simple CLI feature)*

---

## Phase 3: User Story 1 & 2 - Check CLI Version & Discover Version Command via Help (Priority: P1 & P2) 🎯 MVP

**Goal**: As a developer, I want to be able to run `idocs --version` and see `--version` listed in `idocs --help`.

**Independent Test**: Can be tested by running `idocs --version` or `idocs -v` to see "1.3.1" and `idocs --help` to see the version option listed.

### Tests for User Story 1 & 2 (TDD) ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T001 [P] [US1] Unit test `iDocsCLI.configuration.version` equals "1.3.1" in Tests/iDocsTests/iDocsCLITests.swift

### Implementation for User Story 1 & 2

- [x] T002 [P] [US1] Bump package version to 1.3.1 in npm/package.json
- [x] T003 [US1] Update `iDocsCLI.configuration` in Sources/iDocs/Commands/iDocsCLI.swift to include `version: "1.3.1"`

**Checkpoint**: At this point, User Story 1 & 2 should be fully functional and testable independently

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T004 [P] Run quickstart.md validation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 & 2 (P1 & P2)**: Both are addressed simultaneously by updating `CommandConfiguration`.

### Within Each User Story

- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- Updating the `package.json` and `iDocsCLI.swift` can happen in parallel or sequentially.

---

## Implementation Strategy

### MVP First (User Story 1 & 2 Only)

1. Complete Phase 3: User Story 1 & 2
2. **STOP and VALIDATE**: Test User Story 1 & 2 independently
3. Deploy/demo if ready

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Verify tests fail before implementing (if applicable)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
