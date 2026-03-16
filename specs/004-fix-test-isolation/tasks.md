# Tasks: 测试稳定性与网络隔离

**Input**: Design documents from `/specs/004-fix-test-isolation/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: 需求明确包含测试分层与集成测试门禁，以下任务包含测试工作项。

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 测试分层基础准备

- [x] T001 Create test support directory `Tests/iDocsTests/TestSupport/`
- [x] T002 [P] Add integration test gate helper skeleton in `Tests/iDocsTests/TestSupport/IntegrationTestGate.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 统一集成测试开关与测试基线

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Implement integration test gate (env var `IDOCS_INTEGRATION_TESTS`) in `Tests/iDocsTests/TestSupport/IntegrationTestGate.swift`
- [x] T004 [P] Add shared fixture helpers for search/technology payloads in `Tests/iDocsTests/TestSupport/MockPayloads.swift`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - 默认测试稳定可复现 (Priority: P1) 🎯 MVP

**Goal**: 默认测试不访问外部网络，稳定可复现

**Independent Test**: 断网运行默认测试命令 `tuist test iDocs`，测试通过且不访问网络

### Tests for User Story 1 ⚠️

- [x] T005 [P] [US1] Update tool tests to use mocks (no network) in `Tests/iDocsTests/ToolTests.swift`
- [x] T006 [P] [US1] Add unit tests for mock search/technologies payload parsing in `Tests/iDocsTests/ToolTests.swift`

### Implementation for User Story 1

- [x] T007 [US1] Add injectable AppleJSONAPI to `BrowseTechnologiesTool` initializer in `Sources/iDocs/Tools/BrowseTechnologiesTool.swift`
- [x] T008 [P] [US1] Extend mock network session to support search/technology endpoints in `Tests/iDocsTests/Mocks/MockNetworkSession.swift`
- [x] T009 [US1] Inject mocked AppleJSONAPI into `SearchDocsTool` usage in `Tests/iDocsTests/ToolTests.swift`
- [x] T010 [US1] Inject mocked AppleJSONAPI into `BrowseTechnologiesTool` usage in `Tests/iDocsTests/ToolTests.swift`

**Checkpoint**: User Story 1 默认测试稳定可复现

---

## Phase 4: User Story 2 - 显式启用网络集成测试 (Priority: P1)

**Goal**: 显式开关控制网络集成测试执行

**Independent Test**: 设置 `IDOCS_INTEGRATION_TESTS=1` 后运行测试，网络用例执行；未设置时网络用例跳过

### Tests for User Story 2 ⚠️

- [x] T011 [P] [US2] Add integration-gated tests for live search/technologies in `Tests/iDocsTests/IntegrationTests/NetworkToolTests.swift`
- [x] T012 [P] [US2] Gate external DocC live test behind integration switch in `Tests/iDocsTests/IntegrationTests/ExternalDocTests.swift`
- [x] T013 [P] [US2] Add integration test case for network unavailable scenario in `Tests/iDocsTests/IntegrationTests/NetworkToolTests.swift`

### Implementation for User Story 2

- [x] T014 [US2] Apply integration gate in network integration tests via `Tests/iDocsTests/TestSupport/IntegrationTestGate.swift`
- [x] T015 [US2] Support `swift test --filter IntegrationTests` mode in `Tests/iDocsTests/TestSupport/IntegrationTestGate.swift`

**Checkpoint**: 集成测试仅在显式开关下执行

---

## Phase 5: User Story 3 - Apple 文档在线访问一致性 (Priority: P2)

**Goal**: 搜索与技术目录端点构造正确，避免 404

**Independent Test**: 在可用网络下运行集成测试，搜索与技术目录返回有效结果

### Tests for User Story 3 ⚠️

- [x] T016 [P] [US3] Update URL construction tests in `Tests/iDocsTests/IntegrationTests/AppleAPITests.swift`

### Implementation for User Story 3

- [x] T017 [US3] Add explicit URL builders for search/technologies in `Sources/iDocs/Utils/URLHelpers.swift`
- [x] T018 [US3] Update `AppleJSONAPI.search` and `AppleJSONAPI.fetchTechnologies` to use new builders in `Sources/iDocs/DataSources/AppleJSONAPI.swift`

**Checkpoint**: 搜索与技术目录端点不再因 URL 构造错误返回 404

---

## Phase 6: User Story 4 - 第三方 DocC 测试可离线执行 (Priority: P2)

**Goal**: DocC 抓取测试可替换网络层，离线可运行

**Independent Test**: 使用 Mock 网络层运行 DocC 单元测试，离线通过

### Tests for User Story 4 ⚠️

- [x] T019 [P] [US4] Add unit test for ExternalDocCFetcher with mock session in `Tests/iDocsTests/ExternalDocFetcherTests.swift`

### Implementation for User Story 4

- [x] T020 [US4] Inject `NetworkSession` into `ExternalDocCFetcher` in `Sources/iDocs/DataSources/ExternalDocCFetcher.swift`
- [x] T021 [US4] Update existing External DocC tests to use mock session by default in `Tests/iDocsTests/IntegrationTests/ExternalDocTests.swift`

**Checkpoint**: DocC 单元测试离线可运行

---

## Phase 7: User Story 5 - 测试策略文档清晰 (Priority: P3)

**Goal**: 文档明确区分默认测试与集成测试并说明启用方式

**Independent Test**: 阅读文档可清晰区分默认测试与集成测试执行方式

### Implementation for User Story 5

- [x] T022 [P] [US5] Update test execution docs in `README.md`
- [x] T023 [US5] Update test strategy notes in `specs/001-swift-apple-docs-mcp/quickstart.md`

**Checkpoint**: 文档清晰说明测试分层与集成测试开关

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: 收尾与验证

- [x] T024 [P] Run `specs/004-fix-test-isolation/quickstart.md` validation steps
- [x] T025 Add structured failure context for integration tests in `Tests/iDocsTests/IntegrationTests/`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
- **Polish (Phase 8)**: Depends on all desired user stories being complete

### User Story Dependencies

- **US1 (P1)**: Can start after Foundational - no dependencies
- **US2 (P1)**: Can start after Foundational - no dependencies
- **US3 (P2)**: Can start after Foundational - no dependencies
- **US4 (P2)**: Can start after Foundational - no dependencies
- **US5 (P3)**: Can start after Foundational - no dependencies

### Parallel Opportunities

- T005, T006, T008 can run in parallel (different files)
- T011, T012, T013 can run in parallel (different files)
- T016 and T017 can run in parallel (tests + implementation)
- T022 and T023 can run in parallel (documentation)

---

## Parallel Example: User Story 1

```bash
Task: "Update tool tests to use mocks (no network) in Tests/iDocsTests/ToolTests.swift"
Task: "Extend mock network session to support search/technology endpoints in Tests/iDocsTests/Mocks/MockNetworkSession.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: 断网运行默认测试命令验证稳定性

### Incremental Delivery

1. Setup + Foundational → 测试分层基础就绪
2. US1 → 默认测试稳定可复现
3. US2 → 集成测试开关可用
4. US3 → URL 构造修正
5. US4 → DocC 单测离线可运行
6. US5 → 文档补齐
7. Polish → 验收与诊断完善

---

## Notes

- [P] tasks = different files, no dependencies
- 每个用户故事需独立可测试
- 默认测试不访问外部网络，集成测试需显式开启
