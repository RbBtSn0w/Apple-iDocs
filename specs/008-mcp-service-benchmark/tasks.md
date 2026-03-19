# Tasks: 项目级 MCP 接入与四路基准评测

**Input**: Design documents from `/specs/008-mcp-service-benchmark/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: 本特性显式要求可重复验证、统计度量和 rubric 冻结，因此包含测试任务，并按先测后实现组织。

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this belongs to (`[US1]`, `[US2]`, `[US3]`, `[US4]`)
- 所有任务都包含明确文件路径，便于直接执行

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 建立 benchmark 工作区、项目级配置骨架和输入样本目录

- [ ] T001 Create benchmark workspace directories in `specs/008-mcp-service-benchmark/fixtures/.gitkeep`
- [ ] T002 Create project-local MCP config scaffold in `.cursor/mcp.json`
- [ ] T003 [P] Create benchmark environment template in `specs/008-mcp-service-benchmark/fixtures/benchmark.env.example`
- [ ] T004 [P] Create benchmark target registry seed in `specs/008-mcp-service-benchmark/fixtures/targets.json`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 统一记录模型、评分模型、环境隔离与聚合工具

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T005 [P] Add benchmark fixture helpers in `Tests/iDocsTests/TestSupport/BenchmarkFixtures.swift`
- [ ] T006 [P] Add evaluation record schema tests in `Tests/iDocsTests/IntegrationTests/BenchmarkRecordSchemaTests.swift`
- [ ] T007 [P] Add scoring rubric tests in `Tests/iDocsTests/IntegrationTests/BenchmarkRubricTests.swift`
- [ ] T008 Implement benchmark record models in `Sources/iDocs/Commands/BenchmarkRecordModels.swift`
- [ ] T009 Implement benchmark rubric models in `Sources/iDocs/Commands/BenchmarkRubricModels.swift`
- [ ] T010 Implement benchmark common helpers in `scripts/benchmark/common.sh`
- [ ] T011 Implement environment reset runner in `scripts/benchmark/reset-target-state.sh`
- [ ] T012 Implement record aggregation tool in `scripts/benchmark/aggregate-results.swift`

**Checkpoint**: Foundation ready - benchmark target access, task execution, scoring, and rerun flows can be implemented independently

---

## Phase 3: User Story 1 - 项目内完成四个服务的可访问验证 (Priority: P1) 🎯 MVP

**Goal**: 在不修改全局 MCP 设置的前提下，使四个目标都能在项目环境中被发现、探测并输出可识别结果

**Independent Test**: 使用项目内配置启动四个目标的最小验证请求，确认都能返回成功结果或可诊断失败

### Tests for User Story 1 ⚠️

- [ ] T013 [P] [US1] Add target availability tests in `Tests/iDocsTests/IntegrationTests/BenchmarkTargetAvailabilityTests.swift`

### Implementation for User Story 1

- [ ] T014 [US1] Implement project-local MCP bootstrap script in `scripts/benchmark/bootstrap-project-mcp.sh`
- [ ] T015 [US1] Implement minimum target probe runner in `scripts/benchmark/probe-targets.sh`
- [ ] T016 [US1] Store target probe fixtures in `specs/008-mcp-service-benchmark/fixtures/minimum-probes.json`
- [ ] T017 [US1] Document project-local target setup flow in `specs/008-mcp-service-benchmark/quickstart.md`

**Checkpoint**: User Story 1 is functional when the repository can validate four targets without global MCP changes

---

## Phase 4: User Story 2 - 使用统一测试数据执行四路能力测试 (Priority: P1)

**Goal**: 使用共享任务和扩展任务对四个目标执行统一采样，并生成事实记录与证据

**Independent Test**: 对至少一条共享任务执行冷/热样本，输出统一记录字段、tool call 次数、per-call/per-task token 与证据引用

### Tests for User Story 2 ⚠️

- [ ] T018 [P] [US2] Add shared scenario execution tests in `Tests/iDocsTests/IntegrationTests/BenchmarkSharedScenarioTests.swift`
- [ ] T019 [P] [US2] Add cold-warm isolation tests in `Tests/iDocsTests/IntegrationTests/BenchmarkIsolationTests.swift`

### Implementation for User Story 2

- [ ] T020 [P] [US2] Define shared and extended task matrix in `specs/008-mcp-service-benchmark/fixtures/task-matrix.json`
- [ ] T021 [US2] Implement shared scenario runner in `scripts/benchmark/run-shared-scenarios.sh`
- [ ] T022 [US2] Implement cold and warm sample orchestrator in `scripts/benchmark/run-samples.sh`
- [ ] T023 [US2] Implement raw evidence capture pipeline in `scripts/benchmark/capture-evidence.sh`
- [ ] T024 [US2] Extend aggregation logic for `Avg Token per Call`, `Total Token per Task`, and `call_count` in `scripts/benchmark/aggregate-results.swift`
- [ ] T025 [US2] Update evaluation record schema examples in `specs/008-mcp-service-benchmark/contracts/evaluation-record-schema.md`

**Checkpoint**: User Story 2 is functional when a shared task can run across all four targets and produce traceable benchmark records

---

## Phase 5: User Story 3 - 形成面向 AI 使用场景的对比结论 (Priority: P2)

**Goal**: 基于冻结后的 rubric 和格式可消费性模型生成可复核的评分与报告

**Independent Test**: 对一轮 benchmark 结果执行评分，输出总分、维度分解、格式可消费性结果和 `Agent Format Readiness` 章节

### Tests for User Story 3 ⚠️

- [ ] T026 [P] [US3] Add benchmark scoring tests in `Tests/iDocsTests/IntegrationTests/BenchmarkScoringTests.swift`
- [ ] T027 [P] [US3] Add format readiness grading tests in `Tests/iDocsTests/IntegrationTests/BenchmarkFormatReadinessTests.swift`

### Implementation for User Story 3

- [ ] T028 [P] [US3] Create scoring checklist fixtures in `specs/008-mcp-service-benchmark/fixtures/scoring-checklists.json`
- [ ] T029 [P] [US3] Implement scoring engine in `scripts/benchmark/score-results.swift`
- [ ] T030 [P] [US3] Implement format readiness evaluator in `scripts/benchmark/evaluate-format-readiness.swift`
- [ ] T031 [US3] Implement benchmark report renderer with `Agent Format Readiness` section in `scripts/benchmark/render-report.swift`
- [ ] T032 [US3] Update scoring rubric contract with checklist and diagnosability mapping examples in `specs/008-mcp-service-benchmark/contracts/scoring-rubric.md`

**Checkpoint**: User Story 3 is functional when a completed run can be scored and summarized into a report without free-form evaluator judgment

---

## Phase 6: User Story 4 - 支持后续重复复测 (Priority: P3)

**Goal**: 让 benchmark 可以按同一环境说明、rubric 和字段结构重复执行，并比较不同轮次结果

**Independent Test**: 在两轮运行之间生成结构一致的产物，并输出变化对比而非覆盖旧结果

### Tests for User Story 4 ⚠️

- [ ] T033 [P] [US4] Add rerun comparison tests in `Tests/iDocsTests/IntegrationTests/BenchmarkRepeatabilityTests.swift`

### Implementation for User Story 4

- [ ] T034 [P] [US4] Create run manifest template in `specs/008-mcp-service-benchmark/fixtures/run-manifest.json`
- [ ] T035 [US4] Implement rerun comparison script in `scripts/benchmark/compare-runs.sh`
- [ ] T036 [US4] Implement benchmark entrypoint pipeline in `scripts/benchmark/run-008-benchmark.sh`
- [ ] T037 [US4] Update repeatability and rerun instructions in `specs/008-mcp-service-benchmark/quickstart.md`

**Checkpoint**: User Story 4 is functional when a second run can be compared against a baseline with the same schema and rubric

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: 收尾、合同同步、全流程验证

- [ ] T038 [P] Add operator checklist and troubleshooting notes in `specs/008-mcp-service-benchmark/quickstart.md`
- [ ] T039 Normalize target interface examples and failure semantics in `specs/008-mcp-service-benchmark/contracts/target-interface.md`
- [ ] T040 Run full quickstart validation and capture expected outputs in `specs/008-mcp-service-benchmark/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational completion
- **User Story 2 (Phase 4)**: Depends on Foundational completion and uses US1 bootstrap/probe artifacts
- **User Story 3 (Phase 5)**: Depends on Foundational completion and uses US2 execution outputs
- **User Story 4 (Phase 6)**: Depends on Foundational completion and uses US2/US3 run outputs
- **Polish (Phase 7)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependency on other user stories
- **User Story 2 (P1)**: Can start after Foundational, but benefits from US1 target bootstrap/probe flow
- **User Story 3 (P2)**: Depends on benchmark records produced by US2
- **User Story 4 (P3)**: Depends on runnable benchmark pipeline from US2 and report outputs from US3

### Within Each User Story

- Tests MUST be written and fail before implementation
- Fixture and schema tasks before runner scripts
- Runner scripts before report/render/update tasks
- Story checkpoint must pass before the next dependent story starts

### Parallel Opportunities

- `T003` and `T004` can run in parallel in Setup
- `T005`, `T006`, and `T007` can run in parallel in Foundational
- In US2, `T018` and `T019` can run in parallel; `T020` can be prepared alongside them
- In US3, `T026` and `T027` can run in parallel; `T029` and `T030` can run in parallel after `T028`
- In US4, `T033` and `T034` can run in parallel

---

## Parallel Example: User Story 2

```bash
# Launch US2 tests together:
Task: "Add shared scenario execution tests in Tests/iDocsTests/IntegrationTests/BenchmarkSharedScenarioTests.swift"
Task: "Add cold-warm isolation tests in Tests/iDocsTests/IntegrationTests/BenchmarkIsolationTests.swift"

# Prepare US2 fixtures while tests are being authored:
Task: "Define shared and extended task matrix in specs/008-mcp-service-benchmark/fixtures/task-matrix.json"
```

---

## Parallel Example: User Story 3

```bash
# Launch US3 tests together:
Task: "Add benchmark scoring tests in Tests/iDocsTests/IntegrationTests/BenchmarkScoringTests.swift"
Task: "Add format readiness grading tests in Tests/iDocsTests/IntegrationTests/BenchmarkFormatReadinessTests.swift"

# After checklist fixtures exist, implement the two scoring engines in parallel:
Task: "Implement scoring engine in scripts/benchmark/score-results.swift"
Task: "Implement format readiness evaluator in scripts/benchmark/evaluate-format-readiness.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Confirm four targets can be discovered and probed from project-local config

### Incremental Delivery

1. Setup + Foundational → benchmark foundation ready
2. Add User Story 1 → validate project-local target access
3. Add User Story 2 → validate shared task execution and evidence capture
4. Add User Story 3 → validate scoring/report generation
5. Add User Story 4 → validate rerun and diff workflow
6. Finish Polish → run full quickstart validation

### Parallel Team Strategy

1. Team completes Setup + Foundational together
2. After Foundational:
   - Developer A: US1 target access
   - Developer B: US2 execution and capture
   - Developer C: US3 scoring and format analysis
3. US4 starts after US2/US3 outputs are stable

---

## Notes

- [P] tasks are isolated to different files and can be split across contributors
- Story labels map tasks back to spec user stories for traceability
- Each story has an independent validation checkpoint
- Token cost must always be tracked as both per-call and per-task
- Avoid collapsing shared and extended tasks into one score path
