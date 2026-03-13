# Tasks: 提高项目可测试性与单元测试覆盖率

**Input**: Design documents from `specs/002-improve-test-coverage/`
**Prerequisites**: plan.md (✅), spec.md (✅), research.md (✅), data-model.md (✅), contracts/ (✅)

**Tests**: 按照 Constitution III 实施 TDD 流程。单元测试必须在功能重构前编写或同步进行，并确保在注入 Mock 后能够稳定通过。

**Organization**: 任务按用户故事组织，优先解决可测试性架构（US1），随后提升逻辑覆盖率（US2），最后建立自动化门禁（US3）。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 可并行执行（不同文件，无未完成依赖）
- **[Story]**: 任务所属的用户故事（US1, US2, US3）
- 描述中包含确切的文件路径

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 项目结构调整与基础配置更新

- [x] T001 创建目录结构 `Sources/iDocs/Protocols/` 和 `Tests/iDocsTests/Mocks/`
- [x] T002 [P] 更新 `.gitignore` 包含 `coverage_report/` 和 `.xcresult`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 定义核心抽象协议与通用 Mock，这是所有重构任务的前提

**⚠️ CRITICAL**: 在此阶段完成前，无法启动具体的模块重构

- [x] T003 [P] 在 `Sources/iDocs/Protocols/InternalProtocols.swift` 中定义 `NetworkSession` 和 `FileSystem` 协议
- [x] T004 [P] 在 `Sources/iDocs/Protocols/InternalProtocols.swift` 中定义 `SearchProvider` 协议 (Spotlight 抽象)
- [x] T005 [P] 在 `Sources/iDocs/Protocols/InternalProtocols.swift` 中定义 `MockError` 枚举 (包含 5 类核心错误)
- [x] T006 [P] 在 `Tests/iDocsTests/Mocks/MockNetworkSession.swift` 中实现 `MockNetworkSession` (支持 Stubbing 数据与错误)
- [x] T007 [P] 在 `Tests/iDocsTests/Mocks/MockFileSystem.swift` 中实现 `MockFileSystem` (内存虚拟文件系统)
- [x] T008 [P] 在 `Tests/iDocsTests/Mocks/MockSearchProvider.swift` 中实现 `MockSearchProvider` (预设搜索结果)

**Checkpoint**: 基础设施就绪 — 抽象协议与模拟对象可用，重构工作可启动

---

## Phase 3: User Story 1 - 核心模块重构以支持依赖注入 (Priority: P1) 🎯 MVP

**Goal**: 通过构造函数注入抽象协议，彻底解耦核心组件与系统 IO，实现 100% 离线测试

**Independent Test**: 在不具备真实网络和磁盘访问权限的环境下，运行 `AppleJSONAPI` 和 `XcodeLocalDocs` 的注入测试并成功。

- [x] T009 [US1] 重构 `AppleJSONAPI` 以接受 `NetworkSession` 注入 in `Sources/iDocs/DataSources/AppleJSONAPI.swift`
- [x] T010 [US1] 重构 `DiskCache` 以接受 `FileSystem` 注入 in `Sources/iDocs/Cache/DiskCache.swift`
- [x] T011 [US1] 重构 `XcodeLocalDocs` 以接受 `FileSystem` 和 `SearchProvider` 注入 in `Sources/iDocs/DataSources/XcodeLocalDocs.swift`
- [x] T012 [P] [US1] 更新 `SearchDocsTool` 和 `FetchDocTool` 及其成员变量以支持 DI in `Sources/iDocs/Tools/`
- [x] T013 [US1] 更新 `iDocsServer` 以使用默认依赖项（URLSession.shared, FileManager.default）初始化所有组件 in `Sources/iDocs/iDocsServer.swift`

**Checkpoint**: 架构重构完成 — 核心组件现已支持全隔离测试

---

## Phase 4: User Story 2 - 提升核心逻辑与边界情况的覆盖率 (Priority: P1)

**Goal**: 将项目总行覆盖率提升至 80% 以上，核心算法模块（Cache, Rendering, Utils）提升至 90% 以上

**Independent Test**: 执行 `swift test --enable-code-coverage` 并使用 `llvm-cov` 验证覆盖率指标符合 SC-001/SC-002

- [x] T014 [P] [US2] 在 `Tests/iDocsTests/RenderingTests.swift` 中为 `DocCRenderer` 实现覆盖所有 12 种节点的详尽测试
- [x] T015 [P] [US2] 在 `Tests/iDocsTests/IntegrationTests/AppleAPITests.swift` 中利用 Mock 验证 API 错误路径（超时、无效响应）
- [x] T016 [P] [US2] 在 `Tests/iDocsTests/CacheTests.swift` 中利用 Mock 验证 `DiskCache` 边界场景（磁盘满、无权限）
- [x] T017 [P] [US2] 在 `Tests/iDocsTests/XcodeLocalDocsTests.swift` 中利用 Mock 验证 SDK 发现逻辑与 mmap 异常处理
- [x] T018 [P] [US2] 在 `Tests/iDocsTests/CacheTests.swift` 中添加 `MemoryCache` 的高并发稳定性与 LRU 淘汰验证
- [x] T019 [US2] 在 `Tests/iDocsTests/IntegrationTests/TransportTests.swift` 中实现对 `iDocsServer` 启动参数解析逻辑的覆盖

**Checkpoint**: 逻辑覆盖完成 — 核心模块达到 90%+ 覆盖率，所有已知边界情况均有测试保护

---

## Phase 5: User Story 3 - 自动化覆盖率门禁与报告 (Priority: P2)

**Goal**: 建立自动化的质量拦截机制，防止覆盖率在未来开发中回退

**Independent Test**: 修改脚本阈值为 100%，运行 `scripts/coverage-gate.sh` 并确认其正确拦截并退出。

- [x] T020 [US3] 编写 Bash 脚本 `scripts/coverage-gate.sh` 用于解析 `llvm-cov` 输出并实施 80% 硬拦截
- [x] T021 [P] [US3] 编写脚本 `scripts/generate-report.sh` 用于一键生成 HTML 格式的可视化覆盖率报告
- [x] T022 [US3] 在 `specs/002-improve-test-coverage/quickstart.md` 中补充关于 CI 环境配置（macOS 14 + Xcode 15.4）的详细文档

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: 最终代码质量优化与合规性检查

- [x] T023 [P] 彻底清理代码中的 `any` 或 `AnyObject` 滥用，确保 100% 类型安全 per Constitution VII
- [x] T024 [P] 消除 `Sources/iDocs/` 中重复度较高的代码块（>10行），进行必要的私有抽象
- [x] T025 运行 `quickstart.md` 完整验证流程，确保 SC-001 到 SC-005 全量达成

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: 无依赖，立即执行
- **Phase 2 (Foundational)**: 依赖 Phase 1 目录结构
- **Phase 3 (US1 DI 重构)**: 依赖 Phase 2 协议定义，**MVP 核心**
- **Phase 4 (US2 覆盖率提升)**: 依赖 Phase 3 实现的可测试架构
- **Phase 5 (US3 自动化)**: 依赖 Phase 4 产生的测试数据
- **Phase 6 (Polish)**: 依赖所有用户故事完成

### Parallel Opportunities

- Phase 2 内部：T003-T005 (协议定义) 与 T006-T008 (Mock 实现) 可并行
- Phase 4 内部：除 T019 外，所有测试编写任务 (T014-T018) 均可并行执行
- Phase 5 内部：T020 和 T021 可并行开发

---

## Implementation Strategy

### MVP First (Architecture & Core Coverage)

1. 完成 Phase 1 & 2 基础设施搭建
2. 完成 Phase 3 DI 重构，使系统“可测试”
3. 完成 Phase 4 核心模块（Rendering/Cache）的高覆盖率编写
4. **验证点**: 运行全量测试，确认核心模块覆盖率 > 90%

---

## Notes

- 严格遵循“零 Flaky 容忍”原则，所有新增测试必须在 10 次连续运行中保持 100% 通过率
- Mock 实体必须在 `beforeEach` 中显式调用 `reset()`，防止测试间状态污染
- 提交频率：建议每个 TXXX 任务完成后进行原子提交
