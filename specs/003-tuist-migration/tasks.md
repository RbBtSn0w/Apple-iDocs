# Tasks: Migrate project management to Tuist

**Input**: Design documents from `/specs/003-tuist-migration/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/tuist-interface.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure (CRITICAL: Version Pinning)

- [x] T000 [P] Create `.tuist-version` file in root to pin Tuist version per FR-010
- [x] T001 Back up existing `Package.swift` and `Project.swift` to `*.bak` files
- [x] T002 [P] Update `Tuist/Config.swift` with Swift 6.0 and enable Binary Caching per FR-009
- [x] T003 [P] Initialize `Tuist/Package.swift` with core platforms and SPM structure

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Move all external dependencies from root `Package.swift` to `Tuist/Package.swift`
- [x] T005 [P] Implement shared `Settings` object in `Project.swift` to enforce consistency (FR-011)
- [x] T006 [P] Configure target definitions for `iDocs` and `iDocsTests` using shared `Settings`
- [x] T007 [P] Link targets and `.external` dependencies in `Project.swift`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Developer Setup and Project Generation (Priority: P1) 🎯 MVP

**Goal**: Generate the entire Xcode workspace using a single Tuist command.

- [x] T008 [US1] Run `tuist install` to resolve SPM dependencies into `Tuist/.build`
- [x] T009 [US1] Run `tuist generate` to create the `iDocs.xcworkspace`
- [x] T010 [US1] Verify file mapping for `Sources/iDocs/**` and `Tests/iDocsTests/**` in Xcode
- [x] T011 [US1] Perform benchmark for `SC-001` (Project generation < 10 seconds)

---

## Phase 4: User Story 2 - Building, Testing and CI/CD (Priority: P2)

**Goal**: Build/Test consistency across local and CI environments.

- [x] T012 [US2] Run `tuist build` and `tuist test` locally to verify parity
- [x] T013 [US2] Update GitHub Actions workflows (`.github/workflows/*.yml`) to use Tuist CLI (FR-007)
- [x] T014 [US2] Verify CI pipeline passes with `tuist build` and `tuist test` commands

---

## Phase 5: User Story 3 - Dependency Management (Priority: P2)

**Goal**: Manage dependencies using Tuist's integrated SPM support.

- [x] T015 [US3] Add temporary dependency to `Tuist/Package.swift` and run `tuist install`
- [x] T016 [US3] Link and verify dependency usage in a target, then revert

---

## Phase 6: Polish & Cleanup

**Purpose**: Final repository cleanup and documentation

- [x] T017 [P] Remove root `Package.swift`, `.swiftpm/`, and root Xcode artifacts (FR-003)
- [x] T018 [P] Update `.gitignore` to reflect the new Tuist-managed structure
- [x] T019 [P] Update `README.md` and `quickstart.md` with Tuist instructions
- [x] T020 Final verification of all success criteria (SC-001 to SC-004)

---

## Dependencies & Execution Order

- **Phase 1 (Setup)**: MUST complete T000 before any other task.
- **Phase 4 (CI/CD)**: Depends on successful completion of US1 (Phase 3).
- **Phase 6 (Cleanup)**: MUST NOT start until US1 and US2 are fully verified.
