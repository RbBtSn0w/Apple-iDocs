# Tasks: Agent Resolve Documentation Entry

**Input**: Design documents from `/specs/013-agent-resolve-entry/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Required. This feature changes agent-facing behavior, CLI output, adapter contracts, and benchmark issue routing. Test tasks must be written and observed failing before implementation tasks.

**Organization**: Tasks are grouped by user story to enable independently testable increments.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm current feature context and preserve project infrastructure boundaries.

- [x] T001 Confirm active feature directory and available docs with `.specify/scripts/bash/check-prerequisites.sh --json`
- [x] T002 [P] Review resolver contracts in `specs/013-agent-resolve-entry/contracts/resolve-cli.md` and `specs/013-agent-resolve-entry/contracts/documentation-service-resolve.md`
- [x] T003 [P] Review audit layering contract in `specs/013-agent-resolve-entry/contracts/audit-capability-layering.md`
- [x] T004 Verify `.gitignore` already covers Swift, Tuist, Node, and local artifact outputs for this repo

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add typed resolve boundary shared by CLI, adapter, and tool tests.

**CRITICAL**: No user story work can begin until these shared models and protocol seams are in place.

### Tests First

- [x] T005 [P] Write failing adapter contract tests for `ResolveIntent`, `ResolveResult`, and `DocumentationService.resolve(intent:config:)` in `Tests/iDocsAdapterTests/DocumentationServiceContractTests.swift`
- [x] T006 [P] Write failing CLI payload decode tests for resolve JSON fields in `Tests/iDocsTests/CLICommandTests.swift`

### Implementation

- [x] T007 Add resolve models, confidence states, candidate/evidence/diagnostic types, and invalid-intent error shape in `Sources/iDocsAdapter/Models/CoreEntities.swift` and `Sources/iDocsAdapter/Models/DocumentationError.swift`
- [x] T008 Add `resolve(intent:config:)` to `Sources/iDocsAdapter/Protocols/DocumentationService.swift`
- [x] T009 Update `Sources/iDocsAdapter/Adapters/MockDocumentationAdapter.swift` to support configured resolve results and resolve errors
- [x] T010 Extend `Sources/iDocsApp/Commands/CLIOutputModels.swift` with resolve JSON payload fields while preserving search/fetch/list compatibility

**Checkpoint**: Shared typed resolve contract compiles and adapter/CLI model tests can drive implementation.

---

## Phase 3: User Story 1 - Resolve Structured Apple API Intents (Priority: P1) MVP

**Goal**: Agents can call a structured resolver and receive canonical path, confidence, evidence, candidates, and diagnostics.

**Independent Test**: `idocs resolve --framework SwiftUI --symbol NavigationSplitView --json` returns a machine-readable high-confidence result when fetch verification succeeds; invalid structured intents return structured errors without search fallback.

### Tests First

- [x] T011 [P] [US1] Write failing resolver tests for valid intent shapes, default `sourceFamily`, and direct path synthesis in `Tests/iDocsTests/ResolveDocsToolTests.swift`
- [x] T012 [P] [US1] Write failing resolver test for invalid `member` without `type` in `Tests/iDocsTests/ResolveDocsToolTests.swift`
- [x] T013 [P] [US1] Write failing CLI parse and executor tests for `idocs resolve --framework SwiftUI --symbol NavigationSplitView --json` in `Tests/iDocsTests/CLICommandTests.swift`

### Implementation

- [x] T014 [US1] Implement `ResolveDocsTool` path synthesis, source-family defaulting, intent validation, direct candidate creation, and structured diagnostics in `Sources/iDocsKit/Tools/ResolveDocsTool.swift`
- [x] T015 [US1] Wire `DefaultDocumentationAdapter.resolve(intent:config:)` to `ResolveDocsTool` in `Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift`
- [x] T016 [US1] Add `ResolveCommand` and register it in `Sources/iDocsApp/Commands/iDocsCLI.swift`
- [x] T017 [US1] Implement `CLIExecutor.runResolve` JSON and text output in `Sources/iDocsApp/Commands/CLIExecutor.swift`
- [x] T018 [US1] Verify US1 targeted Swift tests pass with `./scripts/tuist-silent.sh test`

**Checkpoint**: User Story 1 is independently usable through adapter and CLI.

---

## Phase 4: User Story 2 - Preserve Fetch as the Evidence Authority (Priority: P1)

**Goal**: Resolver confidence is gated by fetch verification and exposes separate resolver/fetch diagnostics.

**Independent Test**: Valid direct candidates become high confidence only after `FetchDocTool.runDetailed` succeeds; fetch failures cannot produce high confidence.

### Tests First

- [x] T019 [P] [US2] Write failing resolver tests proving fetch failure prevents high confidence in `Tests/iDocsTests/ResolveDocsToolTests.swift`
- [x] T020 [P] [US2] Write failing resolver tests proving search fallback cannot override missing fetch evidence in `Tests/iDocsTests/ResolveDocsToolTests.swift`
- [x] T021 [P] [US2] Write failing CLI JSON test for distinct `resolve_diagnostics` and `fetch_diagnostics` fields in `Tests/iDocsTests/CLICommandTests.swift`

### Implementation

- [x] T022 [US2] Make `ResolveDocsTool` verify every authoritative candidate through `FetchDocTool.runDetailed` and populate evidence payloads in `Sources/iDocsKit/Tools/ResolveDocsTool.swift`
- [x] T023 [US2] Implement high, medium, low, and unresolved confidence assignment in `Sources/iDocsKit/Tools/ResolveDocsTool.swift`
- [x] T024 [US2] Map fetch attempts into resolve results and CLI JSON without merging them into resolver diagnostics in `Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift` and `Sources/iDocsApp/Commands/CLIExecutor.swift`
- [x] T025 [US2] Verify US2 targeted Swift tests pass with `./scripts/tuist-silent.sh test`

**Checkpoint**: Fetch evidence is the authority for resolver confidence.

---

## Phase 5: User Story 4 - Reframe Quality Audits by Capability (Priority: P1)

**Goal**: The random audit and issue collector separate resolve correctness, fetch evidence, and search exploration, and P0 issue automation only covers resolve/fetch golden-truth failures.

**Independent Test**: Node tests prove audit cases have one capability, reports group by capability, and search exploration failures do not create P0 issue fingerprints.

### Tests First

- [x] T026 [P] [US4] Write failing capability schema tests in `scripts/benchmark/tests/search-quality-lib.test.mjs`
- [x] T027 [P] [US4] Write failing issue-collection tests excluding search exploration failures from P0 fingerprints in `scripts/benchmark/tests/search-quality-lib.test.mjs`
- [x] T028 [P] [US4] Write failing random-audit report tests for resolve/search/fetch capability grouping in `scripts/benchmark/tests/run-random-search-audit.test.mjs`

### Implementation

- [x] T029 [US4] Add capability normalization, validation, and P0 issue eligibility helpers in `scripts/benchmark/search-quality-lib.mjs`
- [x] T030 [US4] Update random audit case handling and report output by capability in `scripts/benchmark/run-random-search-audit.mjs`
- [x] T031 [US4] Update fixture expectations for issue #11 and issue #12 capability splitting in `specs/008-mcp-service-benchmark/fixtures/search-audit-pool.json`
- [x] T032 [US4] Verify US4 Node tests pass with `node --test scripts/benchmark/tests/*.test.mjs`

**Checkpoint**: Audit and issue routing reflect the layered evidence quality model.

---

## Phase 6: User Story 3 - Keep Search for Exploration (Priority: P2)

**Goal**: Search remains useful for natural-language, typo, and broad discovery without becoming the P0 resolver correctness path.

**Independent Test**: Search exploration cases remain visible in audit reports, existing search/fetch/list outputs stay compatible, and search failures are not P0 resolver failures by default.

### Tests First

- [x] T033 [P] [US3] Write failing compatibility tests proving existing search/fetch/list JSON outputs remain decodable in `Tests/iDocsTests/CLICommandTests.swift`
- [x] T034 [P] [US3] Write failing benchmark tests showing natural-language search cases stay report-visible but not P0 issue eligible in `scripts/benchmark/tests/search-quality-lib.test.mjs`

### Implementation

- [x] T035 [US3] Preserve search/fetch/list payload compatibility while adding resolve-only fields in `Sources/iDocsApp/Commands/CLIOutputModels.swift`
- [x] T036 [US3] Ensure search exploration failures remain report-visible without resolver-correctness classification in `scripts/benchmark/search-quality-lib.mjs` and `scripts/benchmark/run-random-search-audit.mjs`
- [x] T037 [US3] Verify US3 Swift and Node tests pass with `./scripts/tuist-silent.sh test` and `node --test scripts/benchmark/tests/*.test.mjs`

**Checkpoint**: Search stays exploration-oriented and compatibility is preserved.

---

## Phase 7: Polish & Cross-Cutting Verification

**Purpose**: Full validation, smoke tests, spec status, and task evidence.

- [x] T038 Run full Swift suite with `./scripts/tuist-silent.sh test`
- [x] T039 Run full benchmark script suite with `node --test scripts/benchmark/tests/*.test.mjs`
- [x] T040 Run resolver smoke for SwiftUI exact symbol with `./scripts/tuist-silent.sh run idocs resolve --framework SwiftUI --symbol NavigationSplitView --json`
- [x] T041 Run resolver smoke for AppKit member property with `./scripts/tuist-silent.sh run idocs resolve --framework AppKit --type NSWindow --member toolbarStyle --member-kind property --json`
- [x] T042 Run resolver smoke for UIKit member method with `./scripts/tuist-silent.sh run idocs resolve --framework UIKit --type UIViewController --member present --member-kind method --json`
- [x] T043 Run invalid-intent smoke with `./scripts/tuist-silent.sh run idocs resolve --framework SwiftUI --member body --json`
- [x] T044 Record verification evidence and spec coverage in `specs/013-agent-resolve-entry/tasks.md`
- [x] T045 Run `speckit.superb.verify` and synchronize status to Verified only after all requirements are covered
- [x] T046 Run `speckit.superb.finish` after verification passes and choose the integration action requested by the user

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup and blocks all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational and is the MVP.
- **User Story 2 (Phase 4)**: Depends on US1 resolver structure.
- **User Story 4 (Phase 5)**: Can start after Foundational; implementation may run after US1/US2 to align smoke expectations.
- **User Story 3 (Phase 6)**: Depends on Foundational and audit layering definitions.
- **Polish (Phase 7)**: Depends on desired story phases being complete.

### User Story Dependencies

- **US1**: MVP; no dependency on US2/US3/US4 after Foundational.
- **US2**: Builds on US1 resolver candidates and fetch verification.
- **US4**: Independent from Swift resolver implementation except fixture semantics; can be tested with Node fixtures.
- **US3**: Preserves existing search/fetch/list behavior while audit layering changes.

### Parallel Opportunities

- T002 and T003 can run in parallel.
- T005 and T006 can run in parallel.
- T011, T012, and T013 can run in parallel because they target separate behavior slices.
- T019, T020, and T021 can run in parallel.
- T026, T027, and T028 can run in parallel.
- T033 and T034 can run in parallel.

---

## Implementation Strategy

### MVP First

1. Complete Phase 1 and Phase 2.
2. Complete User Story 1 through `idocs resolve` exact symbol support.
3. Validate US1 independently through Swift tests and one CLI JSON smoke.

### Incremental Delivery

1. Add fetch-gated confidence and diagnostics (US2).
2. Add benchmark capability layering and issue filtering (US4).
3. Preserve search exploration and compatibility behavior (US3).
4. Run full verification and superb gates.

## Notes

- TDD commit steps from generic superpowers guidance are constrained by the repository rule that commits require explicit user direction; green states are recorded in task status and verification evidence instead.
- Mark a task `[x]` only after fresh command output or direct artifact evidence exists.
- Existing dirty worktree changes must be preserved and integrated, not reverted.

## Planning Coverage Review

**Requirements extracted**: 30 functional requirements, 10 success criteria, 13 acceptance scenarios, 10 edge cases.  
**Fully covered**: 53/53 planning requirements.  
**Partially covered**: 0.  
**Gaps identified**: 0.  
**TDD readiness**: READY, with explicit test-first tasks for Swift resolver behavior, adapter contracts, CLI payloads, and Node audit layering.

| Requirement Area | Coverage Tasks | Status |
|------------------|----------------|--------|
| P0 resolver positioning and CLI-first guidance (FR-001, FR-024, Assumptions) | T002, T003, T013, T016, T017, T040-T044 | Covered |
| Resolver inputs and valid intent shapes (FR-002, FR-003, FR-005) | T005, T007-T011, T014, T016, T017 | Covered |
| Invalid intent behavior and no natural-language fallback (FR-004, SC-003, Edge Cases) | T012, T014, T017, T043 | Covered |
| Resolver result payload fields (FR-006, FR-026, SC-001) | T006, T010, T011, T017, T022, T040-T042 | Covered |
| Fetch-gated confidence and evidence authority (FR-007 through FR-014, FR-025, SC-002, SC-006, SC-007) | T019-T025, T040-T042 | Covered |
| Separate resolver and fetch diagnostics (FR-027, FR-028) | T021, T024 | Covered |
| Adapter boundary and mocks (FR-016) | T005, T008, T009, T015 | Covered |
| Backward compatibility for search/fetch/list (FR-015, SC-004) | T006, T010, T033, T035, T037 | Covered |
| Audit capability schema and reporting (FR-017 through FR-020, SC-005, SC-010) | T026, T028-T032, T034, T036, T039 | Covered |
| P0 issue filtering and old issue migration (FR-021 through FR-023, FR-029, FR-030, SC-008, SC-009) | T027, T029-T032, T034, T036 | Covered |

## Verification Evidence

**Fresh verification commands**

- `./scripts/tuist-silent.sh test` — passed; all Swift suites reported `passed`, including `ResolveDocsTool Tests`, `CLI Command Tests`, and `iDocsAdapter Contract Tests`.
- `node --test scripts/benchmark/tests/*.test.mjs` — passed; 20 tests, 20 passing, 0 failing.
- `./scripts/tuist-silent.sh build` — passed with `** BUILD SUCCEEDED **`.
- `git diff --check` — passed with no whitespace errors.
- `speckit.superb.finish` final verification — `./scripts/tuist-silent.sh test` passed again after verification; `node --test scripts/benchmark/tests/*.test.mjs` passed again with 20 tests, 20 passing, 0 failing.
- Finish action — option 3, keep branch as-is. Branch `013-agent-resolve-entry` and current worktree are preserved; spec status remains `Verified`.

**Resolver smoke results**

- SwiftUI exact symbol: `idocs resolve --framework SwiftUI --symbol NavigationSplitView --json` returned `canonical_path=/documentation/swiftui/navigationsplitview`, `confidence=high`, `verified_by_fetch=true`.
- AppKit member property: `idocs resolve --framework AppKit --type NSWindow --member toolbarStyle --member-kind property --json` returned `canonical_path=/documentation/appkit/nswindow/toolbarstyle`, `confidence=high`, `verified_by_fetch=true`.
- UIKit member method: `idocs resolve --framework UIKit --type UIViewController --member present --member-kind method --json` returned `canonical_path=/documentation/uikit/uiviewcontroller/present(_:animated:completion:)`, `confidence=high`, `verified_by_fetch=true`.
- Invalid intent: `idocs resolve --framework SwiftUI --member body --json` returned `exit_category=CONFIG`, `confidence=unresolved`, `verified_by_fetch=false`, and `resolve_diagnostics.reason=invalid_intent`.

## Spec Verification Checklist

- [x] FR-001: Structured resolution is the P0 agent-facing capability — verified by `AGENTS.md`, `iDocsCLI.swift`, and resolver smoke commands.
- [x] FR-002: Resolver accepts framework, symbol, type, member, member kind, source family, JSON, and caller — verified by `CLICommandTests.resolveCommandParsesStructuredIntent`.
- [x] FR-003: Valid structured intent shapes are supported — verified by `ResolveDocsToolTests` direct symbol/type/member cases.
- [x] FR-004: Invalid structured intents return structured errors without search fallback — verified by `ResolveDocsToolTests.rejectsMemberWithoutType` and invalid CLI smoke.
- [x] FR-005: Source family defaults to documentation — verified by `ResolveDocsToolTests.sourceFamilyDefaultsToDocumentation`.
- [x] FR-006: Resolve responses include canonical path, confidence, verification, evidence, candidates, and diagnostics — verified by `CLICommandTests.resolveJSONOutputIncludesEvidenceAndDiagnostics`.
- [x] FR-007: Direct high confidence requires fetch verification — verified by `ResolveDocsToolTests.exactSymbolDirectPath`.
- [x] FR-008: Member high confidence requires matching member evidence — verified by AppKit/UIKit smokes and `ResolveDocsToolTests.knownMemberSignaturePath`.
- [x] FR-009: No high confidence without fetch verification — verified by `ResolveDocsToolTests.directFetchFailurePreventsHighConfidence`.
- [x] FR-010: Search fallback is only candidate recovery after direct failure — verified by `ResolveDocsToolTests.fallbackCannotOverrideMissingFetchEvidence`.
- [x] FR-011: Search fallback cannot override missing fetch evidence — verified by `ResolveDocsToolTests.fallbackCannotOverrideMissingFetchEvidence`.
- [x] FR-012: Fallback confidence requires fetch and structured match — verified by `ResolveDocsTool` fallback confidence tests and Swift full suite.
- [x] FR-013: Unverified or unfetchable results are unresolved or low-confidence candidates — verified by `ResolveDocsToolTests.directFetchFailurePreventsHighConfidence`.
- [x] FR-014: Fetch remains evidence authority — verified by `FetchDocTool Tests` and resolve fetch diagnostics smokes.
- [x] FR-015: Existing search/fetch/list outputs stay compatible — verified by existing `CLI Command Tests`.
- [x] FR-016: Adapter boundary exposes resolve and mocks/contracts support it — verified by `DocumentationServiceContractTests.asyncAPIShape` and `mockResolveResult`.
- [x] FR-017: Audit schema supports resolve/search/fetch capability — verified by `search-quality-lib.test.mjs` capability tests.
- [x] FR-018: Resolve correctness cases cover SwiftUI, AppKit, UIKit, and Foundation — verified by updated `search-audit-pool.json` and Node fixture tests.
- [x] FR-019: Search exploration covers natural language, typo, broad discovery — verified by updated audit fixture and Node tests.
- [x] FR-020: Fetch evidence audit cases verify known canonical paths — verified by `xcode-environment-variable-reference` fetch capability fixture and Node audit tests.
- [x] FR-021: P0 issue automation limited to resolve/fetch failures — verified by `search-quality-lib.test.mjs` P0 eligibility tests.
- [x] FR-022: Natural-language search failures remain report-visible but not P0 fingerprints — verified by `search-quality-lib.test.mjs` and `render-search-quality-summary.test.mjs`.
- [x] FR-023: Prior all-search issue closure is replaced by capability boundaries — verified by `buildIssueCollection` capability filtering tests.
- [x] FR-024: Project guidance states resolve is P0 and iDocs remains CLI-first — verified by `AGENTS.md`.
- [x] FR-025: Confidence states high/medium/low/unresolved are caller-facing — verified by adapter/core models and resolver tests.
- [x] FR-026: Evidence includes source family, source, title/summary, and diagnostics — verified by CLI JSON tests and smoke payloads.
- [x] FR-027: Resolver diagnostics are separate from fetch diagnostics — verified by `CLICommandTests.resolveJSONOutputIncludesEvidenceAndDiagnostics`.
- [x] FR-028: Fetch diagnostics describe source attempts separately — verified by `FetchDocTool Tests` and resolve smokes.
- [x] FR-029: Issue #11 is search exploration unless structured resolve fails — verified by search P0 exclusion tests.
- [x] FR-030: Issue #12 is split across resolve/search/fetch lanes — verified by capability-tagged audit fixture and issue filtering tests.
- [x] SC-001: Structured smoke cases produce machine-readable complete output — verified by three resolve smokes.
- [x] SC-002: No high confidence without fetch verification — verified by `ResolveDocsToolTests.directFetchFailurePreventsHighConfidence`.
- [x] SC-003: Invalid intents return structured errors without search fallback — verified by invalid CLI smoke.
- [x] SC-004: Search/fetch/list compatibility tests continue passing — verified by `./scripts/tuist-silent.sh test`.
- [x] SC-005: Audit cases classify under one capability — verified by Node capability tests.
- [x] SC-006: Resolve audit cases require structured match and fetch evidence — verified by resolver tests and audit fixture.
- [x] SC-007: Fetch evidence audit cases include canonical path, content, and diagnostics — verified by fetch capability fixture and Node suite.
- [x] SC-008: Search exploration failures do not create P0 fingerprints — verified by `actionableIDocsFailures` tests.
- [x] SC-009: P0 automation is limited to resolve/fetch failures — verified by issue collector tests.
- [x] SC-010: Reports expose capability grouping — verified by `run-random-search-audit.test.mjs` and `render-search-quality-summary.test.mjs`.
