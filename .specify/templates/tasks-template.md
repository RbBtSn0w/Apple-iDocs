---

description: "Task list template for feature implementation"
---

# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are REQUIRED for code, CLI, adapter, iDocsKit, diagnostics, and benchmark behavior changes. Documentation-only changes may record a validation task instead of code tests.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **CLI executable**: `Sources/iDocsCLI/`
- **CLI application surface**: `Sources/iDocsApp/`
- **Adapter boundary**: `Sources/iDocsAdapter/`
- **Core runtime**: `Sources/iDocsKit/`
- **Swift tests**: `Tests/iDocsTests/`, `Tests/iDocsAdapterTests/`
- **Benchmark scripts/tests**: `scripts/benchmark/`, `scripts/benchmark/tests/`
- **Spec artifacts**: `specs/[###-feature-name]/`

<!-- 
  ============================================================================
  IMPORTANT: The tasks below are SAMPLE TASKS for illustration purposes only.
  
  The /speckit.tasks command MUST replace these with actual tasks based on:
  - User stories from spec.md (with their priorities P1, P2, P3...)
  - Feature requirements from plan.md
  - Entities from data-model.md
  - CLI/API contracts from contracts/
  
  Tasks MUST be organized by user story so each story can be:
  - Implemented independently
  - Tested independently
  - Delivered as an MVP increment
  
  DO NOT keep these sample tasks in the generated tasks.md file.
  ============================================================================
-->

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Create project structure per implementation plan
- [ ] T002 Initialize [language] project with [framework] dependencies
- [ ] T003 [P] Configure linting and formatting tools

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

Examples of foundational tasks (adjust based on your feature):

- [ ] T004 Add or update public models and error shapes in `Sources/iDocsAdapter/`
- [ ] T005 [P] Add RED adapter/CLI contract tests before implementation
- [ ] T006 [P] Add RED iDocsKit tool tests before implementation
- [ ] T007 Wire shared CLI payload or diagnostics models
- [ ] T008 Configure source/fetch/search diagnostics without merging capability-specific evidence
- [ ] T009 Update benchmark capability fixtures if audit behavior changes

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - [Title] (Priority: P1) 🎯 MVP

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 1 ⚠️

> **NOTE: Write these tests FIRST and record the failing RED result before implementation**

- [ ] T010 [P] [US1] Adapter/CLI contract test for [capability] in `Tests/`
- [ ] T011 [P] [US1] iDocsKit behavior test for [tool/path/diagnostic] in `Tests/iDocsTests/`

### Implementation for User Story 1

- [ ] T012 [P] [US1] Add or update explicit Swift models in `Sources/iDocsAdapter/` or `Sources/iDocsKit/`
- [ ] T013 [US1] Implement core behavior in `Sources/iDocsKit/`
- [ ] T014 [US1] Wire adapter behavior through `Sources/iDocsAdapter/`
- [ ] T015 [US1] Wire CLI command/executor/output in `Sources/iDocsApp/` or `Sources/iDocsCLI/`
- [ ] T016 [US1] Add validation, structured errors, and diagnostics
- [ ] T017 [US1] Add source markers/logging for user story operations

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - [Title] (Priority: P2)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 2 ⚠️

- [ ] T018 [P] [US2] RED contract test for [capability] in `Tests/`
- [ ] T019 [P] [US2] RED integration or benchmark test for [user journey] in `Tests/` or `scripts/benchmark/tests/`

### Implementation for User Story 2

- [ ] T020 [P] [US2] Add or update explicit Swift model for [entity] in `Sources/iDocsAdapter/` or `Sources/iDocsKit/`
- [ ] T021 [US2] Implement [service/tool] in `Sources/iDocsKit/` or `Sources/iDocsAdapter/`
- [ ] T022 [US2] Implement [CLI/feature] in `Sources/iDocsApp/` or `Sources/iDocsCLI/`
- [ ] T023 [US2] Integrate with User Story 1 components (if needed)

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - [Title] (Priority: P3)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 3 ⚠️

- [ ] T024 [P] [US3] RED contract test for [capability] in `Tests/`
- [ ] T025 [P] [US3] RED integration or benchmark test for [user journey] in `Tests/` or `scripts/benchmark/tests/`

### Implementation for User Story 3

- [ ] T026 [P] [US3] Add or update explicit Swift model for [entity] in `Sources/iDocsAdapter/` or `Sources/iDocsKit/`
- [ ] T027 [US3] Implement [service/tool] in `Sources/iDocsKit/` or `Sources/iDocsAdapter/`
- [ ] T028 [US3] Implement [CLI/feature] in `Sources/iDocsApp/` or `Sources/iDocsCLI/`

**Checkpoint**: All user stories should now be independently functional

---

[Add more user story phases as needed, following the same pattern]

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] TXXX [P] Documentation updates in docs/
- [ ] TXXX Code cleanup and refactoring
- [ ] TXXX Performance optimization across all stories
- [ ] TXXX [P] Additional unit or benchmark tests in `Tests/` or `scripts/benchmark/tests/`
- [ ] TXXX Security hardening
- [ ] TXXX Run quickstart.md validation
- [ ] TXXX Run `./scripts/tuist-silent.sh test`
- [ ] TXXX Run `node --test scripts/benchmark/tests/*.test.mjs` if benchmark scripts changed
- [ ] TXXX Run relevant CLI smoke commands, especially `idocs resolve ... --json` for agent-facing evidence changes

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

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - May integrate with US1 but should be independently testable
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - May integrate with US1/US2 but should be independently testable

### Within Each User Story

- Tests MUST be written and FAIL before implementation for code/runtime behavior
- Public models before adapter/CLI wiring
- Core iDocsKit behavior before adapter and CLI output
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- Once Foundational phase completes, all user stories can start in parallel (if team capacity allows)
- All tests for a user story marked [P] can run in parallel
- Models within a story marked [P] can run in parallel
- Different user stories can be worked on in parallel by different team members

---

## Parallel Example: User Story 1

```bash
# Launch all RED tests for User Story 1 together:
Task: "Adapter/CLI contract test for [capability] in Tests/..."
Task: "iDocsKit behavior test for [tool/path/diagnostic] in Tests/iDocsTests/..."

# Launch all models for User Story 1 together:
Task: "Add [Entity1] model in Sources/iDocsAdapter/..."
Task: "Add [Entity2] model in Sources/iDocsKit/..."
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
5. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1
   - Developer B: User Story 2
   - Developer C: User Story 3
3. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
