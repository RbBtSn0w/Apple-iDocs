# Tasks: Search Quality Race CI

**Input**: Design documents from `/specs/012-search-quality-race/`  
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are required by the feature specification and the project constitution. Write failing tests before implementation for every user-visible behavior.

**Organization**: Tasks are grouped by user story so each story can be implemented and verified independently where practical.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on incomplete tasks)
- **[Story]**: Maps to user stories from `spec.md`
- Every task includes concrete file paths

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare directories, shared script module boundaries, and audit fixture location.

- [x] T001 Create benchmark test and fixture directories in `scripts/benchmark/tests/` and `scripts/benchmark/fixtures/`
- [x] T002 Create shared search-quality helper module scaffold in `scripts/benchmark/search-quality-lib.mjs`
- [x] T003 Create initial audit pool file in `specs/008-mcp-service-benchmark/fixtures/search-audit-pool.json`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish shared data contracts, sampler, classification, and iDocs remote-only configuration before story work.

**Critical**: No user story implementation can complete until these tasks are done.

- [x] T004 [P] Write failing Node tests for seeded sampling and `ciEligible=false` exclusion in `scripts/benchmark/tests/search-quality-lib.test.mjs`
- [x] T005 [P] Write failing Node tests for classification and verdict rules in `scripts/benchmark/tests/search-quality-lib.test.mjs`
- [x] T006 [P] Write failing Node tests for issue fingerprint ordering stability in `scripts/benchmark/tests/search-quality-lib.test.mjs`
- [x] T007 [P] Write failing Swift tests for `IDOCS_XCODE_DOC_CACHE_PATH` override in `Tests/iDocsTests/XcodeLocalDocsMockTests.swift`
- [x] T008 [P] Write failing Swift tests for remote-only search JSON diagnostics in `Tests/iDocsTests/CLICommandTests.swift`
- [x] T009 Implement seeded sampler, eligibility filtering, classification, verdict, fingerprint, redaction, and report helper primitives in `scripts/benchmark/search-quality-lib.mjs`
- [x] T010 Implement local Xcode documentation cache override in `Sources/iDocsAdapter/Models/DocumentationConfig.swift`
- [x] T011 Thread the local documentation cache override through adapter/search construction in `Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift` and `Sources/iDocsKit/DataSources/XcodeLocalDocs.swift`
- [x] T012 Expose local-documentation-unavailable diagnostics in CLI JSON output in `Sources/iDocsApp/Commands/CLIExecutor.swift` and `Sources/iDocsApp/Commands/CLIOutputModels.swift`

**Checkpoint**: Shared sampler/classifier/fingerprint logic and iDocs remote-only diagnostics are testable.

---

## Phase 3: User Story 1 - Monitor Search Quality on a Recurring Cadence (Priority: P1) MVP

**Goal**: Scheduled and manual workflow runs the audit without failing for quality-only findings.

**Independent Test**: Inspect workflow structure and run the mock audit path locally to prove the runner can produce completed quality findings and infrastructure failures separately.

### Tests for User Story 1

- [x] T013 [P] [US1] Write failing Node smoke tests for mock audit completion and infrastructure error classification in `scripts/benchmark/tests/run-random-search-audit.test.mjs`
- [x] T014 [P] [US1] Write failing workflow structure test for schedule/manual inputs, permissions, and required stages in `scripts/benchmark/tests/search-quality-workflow.test.mjs`

### Implementation for User Story 1

- [x] T015 [US1] Implement random audit runner with mock-target mode, seed/sample inputs, infrastructure failure exits, and quality non-failing behavior in `scripts/benchmark/run-random-search-audit.mjs`
- [x] T016 [US1] Add `Search Quality Race` workflow with nightly schedule, manual inputs, macOS runner, setup, build, audit, summary, artifact, and issue steps in `.github/workflows/search-quality-race.yml`

**Checkpoint**: User Story 1 can be validated by local mock audit and workflow structure tests.

---

## Phase 4: User Story 2 - Compare iDocs Against Public Competitor Releases (Priority: P1)

**Goal**: iDocs and public npm competitor releases are evaluated against the same seeded sample with exact version traceability.

**Independent Test**: Run installer in dry-run/mock mode and run the audit twice with the same seed to verify identical sample and recorded target versions.

### Tests for User Story 2

- [x] T017 [P] [US2] Write failing Node tests for competitor package-spec parsing and exact-version metadata in `scripts/benchmark/tests/install-corrival-releases.test.mjs`
- [x] T018 [P] [US2] Write failing Node tests that the runner records the same sample for the same seed and includes target versions in `scripts/benchmark/tests/run-random-search-audit.test.mjs`

### Implementation for User Story 2

- [x] T019 [US2] Implement public npm competitor installer with exact resolved version output in `scripts/benchmark/install-corrival-releases.mjs`
- [x] T020 [US2] Integrate installed competitor metadata and per-target execution into `scripts/benchmark/run-random-search-audit.mjs`

**Checkpoint**: User Story 2 can be validated by deterministic sample tests and competitor metadata tests.

---

## Phase 5: User Story 3 - Review Search Quality Evidence Quickly (Priority: P1)

**Goal**: Completed runs produce complete JSON/Markdown artifacts and a concise GitHub Step Summary.

**Independent Test**: Run mock audit and renderer, then inspect generated JSON, Markdown, and summary sections.

### Tests for User Story 3

- [x] T021 [P] [US3] Write failing Node tests for `random-search-audit.json` required fields and raw evidence retention in `scripts/benchmark/tests/run-random-search-audit.test.mjs`
- [x] T022 [P] [US3] Write failing Node tests for summary sections and iDocs failure rows in `scripts/benchmark/tests/render-search-quality-summary.test.mjs`

### Implementation for User Story 3

- [x] T023 [US3] Implement complete JSON and Markdown artifact writing in `scripts/benchmark/run-random-search-audit.mjs`
- [x] T024 [US3] Implement GitHub Step Summary renderer in `scripts/benchmark/render-search-quality-summary.mjs`
- [x] T025 [US3] Wire summary rendering and artifact upload paths in `.github/workflows/search-quality-race.yml`

**Checkpoint**: User Story 3 can be validated by generated artifacts and rendered summary tests.

---

## Phase 6: User Story 4 - Collect iDocs Golden-Truth Failures Automatically (Priority: P1)

**Goal**: Issue collection is idempotent, scoped only to actionable iDocs failures, and testable without live mutation.

**Independent Test**: Run issue collector in dry-run mode for no-failure, new-failure, and repeated-fingerprint fixtures.

### Tests for User Story 4

- [x] T026 [P] [US4] Write failing Node tests for no-failure no-op and network/infra exclusion in `scripts/benchmark/tests/create-search-quality-issue.test.mjs`
- [x] T027 [P] [US4] Write failing Node tests for issue body content, fingerprint lookup, and duplicate-comment behavior in `scripts/benchmark/tests/create-search-quality-issue.test.mjs`

### Implementation for User Story 4

- [x] T028 [US4] Implement issue collector dry-run, print-body, fingerprint lookup, create, comment, and best-effort label behavior in `scripts/benchmark/create-search-quality-issue.mjs`
- [x] T029 [US4] Add reusable issue body/comment rendering and mock GitHub fixtures in `scripts/benchmark/search-quality-lib.mjs` and `scripts/benchmark/fixtures/mock-target-results.json`
- [x] T030 [US4] Wire issue collection with `GITHUB_TOKEN` and run URL metadata in `.github/workflows/search-quality-race.yml`

**Checkpoint**: User Story 4 can be validated locally with dry-run fixtures and in CI with simulated failure mode.

---

## Phase 7: User Story 5 - Keep the Race Remote-Only for CI (Priority: P2)

**Goal**: CI race results exclude local Xcode documentation cache comparison and preserve the diagnostic.

**Independent Test**: Run iDocs with a nonexistent documentation cache path and confirm JSON diagnostics and audit report state local comparison is excluded.

### Tests for User Story 5

- [x] T031 [P] [US5] Write failing Node tests that audit artifacts include `remoteOnly=true` and local-comparison-excluded text in `scripts/benchmark/tests/run-random-search-audit.test.mjs`
- [x] T032 [P] [US5] Extend Swift tests for nonexistent `IDOCS_XCODE_DOC_CACHE_PATH` continuing remote fallback with diagnostics in `Tests/iDocsTests/CLICommandTests.swift`

### Implementation for User Story 5

- [x] T033 [US5] Set the workflow's iDocs local documentation cache path to a nonexistent temp path in `.github/workflows/search-quality-race.yml`
- [x] T034 [US5] Include remote-only diagnostics in audit artifacts and summaries in `scripts/benchmark/run-random-search-audit.mjs` and `scripts/benchmark/render-search-quality-summary.mjs`

**Checkpoint**: User Story 5 can be validated by Swift diagnostics tests and artifact contract tests.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, validation, and final gates.

- [x] T035 [P] Update `specs/012-search-quality-race/quickstart.md` if command names or output paths changed during implementation
- [x] T036 Run Node script test suite with `node --test scripts/benchmark/tests/*.test.mjs`
- [x] T037 Run Swift test suite with `./scripts/tuist-silent.sh test`
- [x] T038 Run local mock audit smoke test from `specs/012-search-quality-race/quickstart.md`
- [x] T039 Run issue collector dry-run/print-body smoke test from `specs/012-search-quality-race/quickstart.md`
- [x] T040 Run workflow static validation through the workflow structure tests in `scripts/benchmark/tests/search-quality-workflow.test.mjs`
- [x] T041 Mark this task list complete only after all implementation tasks and verification evidence are recorded in `specs/012-search-quality-race/tasks.md`

## Verification Evidence

- T036: `node --test scripts/benchmark/tests/*.test.mjs` passed 16/16 tests.
- T037: `./scripts/tuist-silent.sh test` passed all reported suites, including `CLI Command Tests`, `XcodeLocalDocs Mock Tests`, `XcodeLocalDocs Integration Tests`, and `SearchDocsTool Integration Tests`.
- T038: `node scripts/benchmark/run-random-search-audit.mjs --seed 1 --sample-size 6 --mock-targets scripts/benchmark/fixtures/mock-target-results.json --output-dir /tmp/idocs-search-quality-race` completed and wrote `random-search-audit.json` and `random-search-audit.md`.
- T039: `node scripts/benchmark/create-search-quality-issue.mjs --input /tmp/idocs-search-quality-race/random-search-audit.json --dry-run --print-body` returned `{"action":"none"}`; mock-failure dry-run rendered an issue body with fingerprint, CI run URL, failing cases, diagnostics, competitor versions, artifact path, and reproduction command.
- T040: `node --test scripts/benchmark/tests/search-quality-workflow.test.mjs` passed 1/1 tests.
- Additional live competitor smoke: real npm install into `/tmp/idocs-corrival-probe` retained all default packages and `node scripts/benchmark/run-random-search-audit.mjs --seed 1 --sample-size 1 --versions-file /tmp/idocs-corrival-versions.json --idocs-binary /usr/bin/true --output-dir /tmp/idocs-search-quality-live-smoke` completed, exercising live MCP/CLI competitor execution paths without failing the runner for quality findings.
- Build gate: `./scripts/tuist-silent.sh build iDocs` passed with `** BUILD SUCCEEDED **`; `test -x "$IDOCS_CLI_BINARY"` verifies the workflow path resolves to the freshly built CLI. `tuist-silent.sh` refreshes the generated workspace when manifest inputs are newer, `IDOCS_TUIST_FORCE_GENERATE=1` is set, or the first xcodebuild attempt exposes a stale workspace.
- CLI remote-only gate: `IDOCS_XCODE_DOC_CACHE_PATH=/tmp/idocs-nonexistent-doc-cache ./scripts/tuist-silent.sh run idocs search "SwiftUI NavigationSplitView" --json` exited 0, returned a symbol hit through remote fallback, and included `search_diagnostics[].reason == "local_docs_unavailable"`.

## Spec Verification Checklist

- [x] US1 recurring/manual monitor: `.github/workflows/search-quality-race.yml` has `schedule` and `workflow_dispatch`; `scripts/benchmark/tests/search-quality-workflow.test.mjs` and mock audit smoke validate stages and quality-vs-infra behavior.
- [x] US2 competitor comparison: `install-corrival-releases.mjs`, `run-random-search-audit.mjs`, deterministic sample tests, package metadata tests, and live competitor smoke verify same seeded sample plus exact npm release metadata.
- [x] US3 evidence review: `run-random-search-audit.test.mjs` and `render-search-quality-summary.test.mjs` verify JSON artifact, Markdown artifact, Step Summary sections, raw evidence retention, and iDocs failure rows.
- [x] US4 issue collection: `create-search-quality-issue.test.mjs` verifies no-op, body rendering, fingerprint lookup, duplicate comment behavior, and simulated-failure labeling.
- [x] US5 remote-only CI: Swift CLI tests plus the CLI remote-only gate verify `IDOCS_XCODE_DOC_CACHE_PATH`, `local_docs_unavailable`, and report text excluding local Xcode comparison.
- [x] FR-001/FR-002: workflow structure test covers nightly schedule, manual dispatch, `seed`, `sample_size`, `package_spec`, and `mock_failure`.
- [x] FR-003: workflow build step and build gate cover building the current repository `idocs` CLI.
- [x] FR-004/FR-005: installer tests and live install smoke cover default npm competitors and exact resolved versions.
- [x] FR-006/FR-007: seeded sampler tests cover deterministic same-seed selection and `ciEligible=false` exclusion.
- [x] FR-008/FR-010: audit-pool schema inspection confirms required fields and query-shape coverage.
- [x] FR-009: audit-pool schema inspection confirms SwiftUI, AppKit, UIKit, Foundation, Xcode, and App Store Connect coverage.
- [x] FR-011/FR-014: classification/verdict tests cover supported classifications, invalid/no-result empty pass, and module-only fail rules.
- [x] FR-015/FR-016: workflow env, runner metadata, Swift tests, and CLI remote-only gate cover remote-only diagnostics and local comparison exclusion.
- [x] FR-017/FR-018: mock audit quality-failure test exits 0; mock infrastructure failure exits nonzero; workflow lacks `continue-on-error` on build/install/audit/render/upload/issue steps.
- [x] FR-019/FR-023: runner and renderer tests cover machine-readable artifact, human-readable report, summary sections, iDocs failure repro commands, and cross-product comparison rows.
- [x] FR-024/FR-029: issue collector tests cover iDocs-only actionable failures, stable fingerprinting, duplicate comment path, new issue body, label fallback path, and no-failure no-op.
- [x] FR-030: mock-failure tests cover simulated iDocs failure injection and mark reports/issues as automation validation, not product regression.
- [x] SC-001/SC-014: Node tests, Swift tests, workflow static validation, quickstart smokes, live competitor smoke, build gate, and CLI remote-only gate collectively verify all measurable outcomes.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup; blocks all story implementation.
- **US1 (Phase 3)**: Depends on Foundational; MVP workflow and runner path.
- **US2 (Phase 4)**: Depends on Foundational and US1 runner shape.
- **US3 (Phase 5)**: Depends on US1 runner output shape and US2 target metadata.
- **US4 (Phase 6)**: Depends on US3 artifact/result shape.
- **US5 (Phase 7)**: Depends on Foundational remote-only config and US3 reporting.
- **Polish (Phase 8)**: Depends on selected user stories being complete.

### User Story Dependencies

- **User Story 1**: Required MVP.
- **User Story 2**: Extends runner target metadata.
- **User Story 3**: Extends runner output into artifacts and summaries.
- **User Story 4**: Consumes US3 artifacts and iDocs failure results.
- **User Story 5**: Cross-cuts Swift diagnostics, runner metadata, and workflow environment.

### TDD Order

- Write each test task first.
- Run the target command and observe failure.
- Implement the smallest production/script change to pass.
- Re-run the targeted test and then broader relevant test suite.
- Mark the task done only after fresh evidence exists.

## Parallel Opportunities

- T004 through T008 can be written in parallel because they touch different test concerns.
- T013 and T014 can be written in parallel.
- T017 and T018 can be written in parallel.
- T021 and T022 can be written in parallel.
- T026 and T027 can be written in parallel.
- T031 and T032 can be written in parallel.
- Polish validation commands can run after implementation in the listed dependency order.

## Implementation Strategy

### MVP First

1. Complete Setup and Foundational tasks.
2. Complete US1 to get a scheduled/manual workflow shell and local mock runner.
3. Validate quality-vs-infrastructure behavior before adding competitor installs, reports, and issues.

### Incremental Delivery

1. Add US2 competitor release metadata and shared seeded samples.
2. Add US3 artifacts and summaries.
3. Add US4 issue collection.
4. Add US5 remote-only diagnostics across Swift and CI.

## Notes

- Optional git commit hooks are not executed unless explicitly requested.
- TDD commit steps from generic superpowers guidance are constrained by the repository rule that commits require explicit user direction; green states are recorded in task status and verification evidence instead.
