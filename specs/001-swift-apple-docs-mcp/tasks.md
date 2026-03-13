# Tasks: Swift 原生 Apple 文档 MCP 服务器

**Input**: Design documents from `specs/001-swift-apple-docs-mcp/`
**Prerequisites**: plan.md (✅), spec.md (✅), research.md (✅), data-model.md (✅), contracts/ (✅)

**Tests**: Constitution Principle III (测试先行) 要求 TDD，所有用户故事包含测试任务。

**Organization**: 任务按用户故事分组，支持独立实现和测试。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 可并行执行（不同文件，无依赖）
- **[Story]**: 所属用户故事（US1, US2, US3...）
- 包含精确文件路径

---

## Phase 1: Setup (项目初始化)

**Purpose**: 项目骨架和基础配置

- [ ] T001 创建 `Package.swift` 声明 SPM 依赖 (`modelcontextprotocol/swift-sdk` v0.11.0+, `swift-service-lifecycle` v2.3.0+, `swift-log`) in `Package.swift`
- [ ] T002 创建 `Project.swift` Tuist 工程描述 in `Project.swift`
- [ ] T003 [P] 创建 `Tuist/Config.swift` Tuist 配置 in `Tuist/Config.swift`
- [ ] T004 [P] 创建项目目录结构 `Sources/iDocs/Tools/`, `Sources/iDocs/DataSources/`, `Sources/iDocs/Rendering/`, `Sources/iDocs/Cache/`, `Sources/iDocs/Utils/`, `Tests/iDocsTests/`, `Tests/iDocsTests/IntegrationTests/`
- [ ] T005 [P] 创建 `.gitignore` 添加 Swift/Xcode/Tuist 忽略规则 in `.gitignore`

---

## Phase 2: Foundational (基础设施 — 阻塞所有用户故事)

**Purpose**: 核心基础设施，MUST 全部完成后才能启动用户故事

**⚠️ CRITICAL**: 所有用户故事依赖此阶段的完成

### 测试 ⚠️

- [ ] T006 [P] 编写 `MemoryCache` 单元测试（LRU 淘汰、容量限制、过期清理）in `Tests/iDocsTests/CacheTests.swift`
- [ ] T007 [P] 编写 `DiskCache` 单元测试（TTL 过期、读写、磁盘持久化）in `Tests/iDocsTests/CacheTests.swift`

### 实现

- [ ] T008 定义 DocC Codable 类型体系（`DocumentKind`, `SourceLanguage`, `DataSource`, `DocCContent`, `ContentBlock`, `InlineContent`）in `Sources/iDocs/Rendering/DocCTypes.swift`
- [ ] T009 [P] 实现 `MemoryCache` Actor（LRU 缓存，容量可配置，O(1) 查找/淘汰）in `Sources/iDocs/Cache/MemoryCache.swift`
- [ ] T010 [P] 实现 `DiskCache`（`~/Library/Caches/iDocs/` 持久化，TTL 分级过期，JSON 编码）in `Sources/iDocs/Cache/DiskCache.swift`
- [ ] T011 [P] 实现 `UserAgentPool`（12+ UA 随机轮换，403/429 自动重试，指数退避）in `Sources/iDocs/Utils/UserAgentPool.swift`
- [ ] T012 [P] 实现 `URLHelpers`（Apple 文档 URL 解析/转换，路径规范化）in `Sources/iDocs/Utils/URLHelpers.swift`
- [ ] T013 实现 MCP Server 主入口 `iDocsServer`（Server 初始化、capabilities 声明、Transport 切换、ServiceLifecycle 集成、`swift-log` 配置）in `Sources/iDocs/iDocsServer.swift`

**Checkpoint**: 基础设施就绪 — 缓存层可用、Server 骨架运行、类型系统定义完成

---

## Phase 3: User Story 1 — 搜索 Apple 文档 (Priority: P1) 🎯 MVP

**Goal**: AI 助手可以搜索 Apple 文档，获取结构化搜索结果列表

**Independent Test**: 发送搜索关键词 "SwiftUI View" 并验证返回搜索结果列表

### 测试 ⚠️

- [ ] T014 [P] [US1] 编写 `AppleJSONAPI` 数据源单元测试（URL 构建、响应解析、错误处理）in `Tests/iDocsTests/IntegrationTests/AppleAPITests.swift`
- [ ] T015 [P] [US1] 编写 `SearchDocsTool` 集成测试（通配符匹配、结果格式、三层回落）in `Tests/iDocsTests/ToolTests.swift`

### 实现

- [ ] T016 [US1] 实现 `AppleJSONAPI` 数据源（`developer.apple.com/tutorials/data` 接口，搜索 + 文档获取，UserAgent 池集成）in `Sources/iDocs/DataSources/AppleJSONAPI.swift`
- [ ] T017 [US1] 实现 `SearchDocsTool` MCP 工具（输入 schema 定义，通配符 `*`/`?` 解析，三层回落搜索逻辑，Markdown 结果格式化）in `Sources/iDocs/Tools/SearchDocsTool.swift`
- [ ] T018 [US1] 在 `iDocsServer` 中注册 `SearchDocsTool`（`withMethodHandler(ListTools)` + `withMethodHandler(CallTool)` 路由）in `Sources/iDocs/iDocsServer.swift`

**Checkpoint**: User Story 1 独立可用 — 搜索工具可通过 MCP Inspector 测试

---

## Phase 4: User Story 2 — 获取完整文档内容 (Priority: P1)

**Goal**: AI 助手获取指定文档的完整高质量 Markdown 内容

**Independent Test**: 请求 `/documentation/swiftui/view` 并验证返回完整 Markdown（含声明、参数、代码示例）

### 测试 ⚠️

- [ ] T019 [P] [US2] 编写 `DocCRenderer` 单元测试（各节点类型渲染、递归深度保护、边界情况、golden file 对比验证 SC-003 语义结构 100% 保留）in `Tests/iDocsTests/RenderingTests.swift`

### 实现

- [ ] T020 [US2] 实现 `DocCRenderer`（DocC JSON → Markdown，覆盖 declarations/parameters/properties/content/tables/aside/codeListing/images/relationship/topic/seeAlso，递归深度保护 50 层 content + 20 层 inline）in `Sources/iDocs/Rendering/DocCRenderer.swift`
- [ ] T021 [US2] 实现大文档截断策略（FR-024：体积 >100KB 时按优先级截断代码清单/示例/参考，保留核心声明与参数）in `Sources/iDocs/Rendering/DocCRenderer.swift`
- [ ] T022 [US2] 实现 `FetchDocTool` MCP 工具（路径解析，本地缓存优先 → 在线获取，调用 DocCRenderer 渲染，缓存结果）in `Sources/iDocs/Tools/FetchDocTool.swift`
- [ ] T023 [US2] 在 `iDocsServer` 中注册 `FetchDocTool` in `Sources/iDocs/iDocsServer.swift`

**Checkpoint**: User Story 2 独立可用 — 文档获取工具返回高质量 Markdown

---

## Phase 5: User Story 3 — 查询 Xcode 本地已下载文档 (Priority: P1) ⭐ 核心差异化

**Goal**: AI 助手直接查询 Xcode 本地文档，离线可用

**Independent Test**: 查询已知存在的本地符号 "Array.append" 并验证返回本地文档内容

### 测试 ⚠️

- [ ] T023 [P] [US3] 编写 `XcodeLocalDocs` 集成测试（文档发现、索引读取、符号查询、mmap 读取）in `Tests/iDocsTests/XcodeLocalDocsTests.swift`

### 实现

- [ ] T024 [US3] 实现 `XcodeLocalDocs` 数据源（`~/Library/Developer/Xcode/DocumentationCache/` 发现、`Data(contentsOf:options:.mappedIfSafe)` mmap 读取、LMDB C 桥接索引访问、Spotlight `NSMetadataQuery` 全量模糊搜索）in `Sources/iDocs/DataSources/XcodeLocalDocs.swift`
- [ ] T025 [US3] 实现 `XcodeDocsTool` MCP 工具（`search` 模式符号查询 + `list` 模式文档集列出，回落建议）in `Sources/iDocs/Tools/XcodeDocsTool.swift`
- [ ] T026 [US3] 在 `iDocsServer` 中注册 `XcodeDocsTool` in `Sources/iDocs/iDocsServer.swift`
- [ ] T027 [US3] 将 `XcodeLocalDocs` 集成到 `SearchDocsTool` 的三层回落逻辑（优先查询本地层）in `Sources/iDocs/Tools/SearchDocsTool.swift`

**Checkpoint**: User Story 3 独立可用 — Xcode 本地文档查询离线工作

---

## Phase 6: User Story 4 — 浏览 Apple 技术目录 (Priority: P2)

**Goal**: AI 助手浏览 Apple 技术框架分类目录

**Independent Test**: 请求技术目录并验证返回分类列表

### 测试 ⚠️

- [ ] T028 [P] [US4] 编写 `BrowseTechnologiesTool` 集成测试 in `Tests/iDocsTests/ToolTests.swift`

### 实现

- [ ] T029 [US4] 实现 `BrowseTechnologiesTool` MCP 工具（获取 Apple 技术目录 JSON，分类筛选，Markdown 格式化，缓存 TTL 2h）in `Sources/iDocs/Tools/BrowseTechnologiesTool.swift`
- [ ] T030 [US4] 在 `iDocsServer` 中注册 `BrowseTechnologiesTool` in `Sources/iDocs/iDocsServer.swift`

**Checkpoint**: User Story 4 独立可用

---

## Phase 7: User Story 5 — 获取 HIG 人机界面指南 (Priority: P2)

**Goal**: AI 助手获取 Apple HIG 指定主题内容

**Independent Test**: 请求 HIG 主题 "navigation" 并验证返回完整内容

### 测试 ⚠️

- [ ] T031 [P] [US5] 编写 `HIGFetcher` & `FetchHIGTool` 集成测试 in `Tests/iDocsTests/IntegrationTests/HIGTests.swift`

### 实现

- [ ] T032 [US5] 实现 `HIGFetcher` 数据源（HIG 内容获取与解析，HTML → Markdown 转换）in `Sources/iDocs/DataSources/HIGFetcher.swift`
- [ ] T033 [US5] 实现 `FetchHIGTool` MCP 工具（主题解析，缓存 TTL 24h，错误提示）in `Sources/iDocs/Tools/FetchHIGTool.swift`
- [ ] T034 [US5] 在 `iDocsServer` 中注册 `FetchHIGTool` in `Sources/iDocs/iDocsServer.swift`

**Checkpoint**: User Story 5 独立可用

---

## Phase 8: User Story 6 — 获取第三方 Swift-DocC 文档 (Priority: P2)

**Goal**: AI 助手查询第三方 Swift 包的 DocC 文档

**Independent Test**: 请求一个已知的第三方 DocC 文档 URL 并验证返回 Markdown 内容

### 测试 ⚠️

- [ ] T035 [P] [US6] 编写 `ExternalDocCFetcher` & `FetchExternalDocTool` 集成测试 in `Tests/iDocsTests/IntegrationTests/ExternalDocTests.swift`

### 实现

- [ ] T036 [US6] 实现 `ExternalDocCFetcher` 数据源（第三方 DocC URL 验证、JSON 获取、复用 DocCRenderer 渲染）in `Sources/iDocs/DataSources/ExternalDocCFetcher.swift`
- [ ] T037 [US6] 实现 `FetchExternalDocTool` MCP 工具（URL 校验，缓存，错误处理）in `Sources/iDocs/Tools/FetchExternalDocTool.swift`
- [ ] T038 [US6] 在 `iDocsServer` 中注册 `FetchExternalDocTool` in `Sources/iDocs/iDocsServer.swift`

**Checkpoint**: User Story 6 独立可用

---

## Phase 9: User Story 7 — 获取 WWDC 视频转录 (Priority: P3)

**Goal**: AI 助手获取 WWDC 视频文字转录

**Independent Test**: 请求已知 WWDC 视频 ID 并验证返回转录内容

### 测试 ⚠️

- [ ] T039 [P] [US7] 编写 `FetchVideoTranscriptTool` 集成测试 in `Tests/iDocsTests/ToolTests.swift`

### 实现

- [ ] T040 [US7] 实现 `FetchVideoTranscriptTool` MCP 工具（videoID 解析，在线抓取转录，缓存，错误处理）in `Sources/iDocs/Tools/FetchVideoTranscriptTool.swift`
- [ ] T041 [US7] 在 `iDocsServer` 中注册 `FetchVideoTranscriptTool` in `Sources/iDocs/iDocsServer.swift`

**Checkpoint**: User Story 7 独立可用

---

## Phase 10: User Story 8 — 双模式连接 (Priority: P2)

**Goal**: 支持 Stdio + HTTP 双模式传输

**Independent Test**: 分别以两种模式启动服务器并发送工具调用请求

### 测试 ⚠️

- [ ] T042 [P] [US8] 编写传输连接集成测试（Stdio 交互验证、HTTP Server 响应验证）in `Tests/iDocsTests/IntegrationTests/TransportTests.swift`

### 实现

- [ ] T043 [US8] 扩展 `iDocsServer` 支持命令行参数解析（`--transport stdio|http`, `--port 8080`）in `Sources/iDocs/iDocsServer.swift`
- [ ] T044 [US8] 集成 `StatefulHTTPServerTransport`（会话管理 + SSE 流式推送）in `Sources/iDocs/iDocsServer.swift`

**Checkpoint**: 双模式连接可用

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: 全局优化、验收门禁和收尾

### 端到端测试与日志

- [ ] T045 [P] 编写 MCP Server 端到端测试（InMemoryTransport 模式下 7 工具独立调用验证 SC-007，含离线场景断言 SC-004：已缓存功能断网可用）in `Tests/iDocsTests/IntegrationTests/ServerTests.swift`
- [ ] T046 [P] 完善 MCP `server.log()` 日志推送（关键事件：文档发现、缓存命中/未中、API 回落、错误降级）+ 在 T045 中添加日志断言验证 SC-010 in `Sources/iDocs/iDocsServer.swift`

### 性能基准验证 (G2: SC-001/002/006/008/009)

- [ ] T047 [P] 编写性能基准测试：搜索响应 ≤2s (SC-001)、本地符号定位 p95 ≤100ms (SC-002)、缓存命中 ≥10x 加速 (SC-008)、优雅关闭 ≤5s (SC-009) in `Tests/iDocsTests/IntegrationTests/BenchmarkTests.swift`
- [ ] T048 [P] 编写 UserAgent 重试成功率测试：模拟 403/429 响应，断言自动重试成功率 ≥90% (SC-006) in `Tests/iDocsTests/ToolTests.swift`

### 产物验收 (G1: FR-018/SC-005)

- [ ] T049 [P] 编写 Distribution Validation 脚本：`otool -L` 动态依赖扫描（断言零外部 dylib）、`ls -lh` 体积门禁 ≤20MB (SC-005)、确认 static Mach-O 产物类型 in `scripts/validate-distribution.sh`

### 文档与收尾

- [ ] T050 [P] 创建 README.md（至少包含：项目简介、安装步骤、AI 客户端配置、7 工具列表、贡献指南）**DoD**: 覆盖 quickstart 全流程 in `README.md`
- [ ] T051 代码清理和重构 **DoD**: 零编译警告、全量测试通过、无 `any`/`AnyObject` 残留、无重复代码块 >10 行
- [ ] T052 运行 `quickstart.md` 完整验证流程（编译、MCP Inspector 连接、全部 7 工具调用测试、性能基准通过、产物验收通过）

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: 无依赖 — 立即开始
- **Phase 2 (Foundational)**: 依赖 Phase 1 — **阻塞**所有用户故事
- **Phase 3 (US1 搜索)**: 依赖 Phase 2
- **Phase 4 (US2 文档获取)**: 依赖 Phase 2 + T008 (DocCTypes)
- **Phase 5 (US3 Xcode 本地)**: 依赖 Phase 2 + Phase 3 (T017 SearchDocsTool 用于集成回落)
- **Phase 6 (US4 技术目录)**: 依赖 Phase 2
- **Phase 7 (US5 HIG)**: 依赖 Phase 2
- **Phase 8 (US6 第三方 DocC)**: 依赖 Phase 2 + T020 (DocCRenderer)
- **Phase 9 (US7 WWDC 转录)**: 依赖 Phase 2
- **Phase 10 (US8 双模式)**: 依赖 Phase 2 + T013 (iDocsServer)
- **Phase 11 (Polish)**: 依赖所有用户故事完成

### User Story Dependencies

- **US1 (搜索)**: Phase 2 后可开始 — 无其他故事依赖
- **US2 (文档获取)**: Phase 2 后可开始 — 与 US1 并行（共享 AppleJSONAPI）
- **US3 (Xcode 本地)**: 依赖 US1 (SearchDocsTool 回落集成)
- **US4 (技术目录)**: Phase 2 后可开始 — 与 US1/US2 并行
- **US5 (HIG)**: Phase 2 后可开始 — 独立
- **US6 (第三方 DocC)**: 依赖 US2 (复用 DocCRenderer)
- **US7 (WWDC 转录)**: Phase 2 后可开始 — 独立
- **US8 (双模式)**: Phase 2 后可开始 — 独立

### Parallel Opportunities

```text
Phase 2 内部并行:
  T006, T007 (测试) | T009, T010, T011, T012 (缓存+工具) — 并行

Phase 2 后可并行启动:
  US1 (搜索) | US2 (文档获取) | US4 (技术目录) | US5 (HIG) | US7 (WWDC) — 并行

US1 完成后:
  US3 (Xcode 本地) — 依赖 US1

US2 完成后:
  US6 (第三方 DocC) — 依赖 US2
```

---

## Implementation Strategy

### MVP First (User Story 1 + 2 + 3)

1. 完成 Phase 1: Setup
2. 完成 Phase 2: Foundational (**阻塞**)
3. 完成 Phase 3: US1 搜索
4. 完成 Phase 4: US2 文档获取
5. 完成 Phase 5: US3 Xcode 本地
6. **停止并验证**: 通过 MCP Inspector 测试核心 3 工具
7. 部署/演示 MVP

### Incremental Delivery

1. Setup + Foundational → 基础就绪
2. US1 (搜索) → 测试独立 → MVP 搜索能力
3. US2 (文档获取) → 测试独立 → 完整文档体验
4. US3 (Xcode 本地) → 测试独立 → 核心差异化特性
5. US4-US8 逐步增量交付
6. Polish → 最终发布

---

## Notes

- [P] 任务 = 不同文件，无依赖，可并行
- [Story] 标签映射到 spec.md 中的用户故事
- Constitution 要求 TDD：先写测试、确认失败、再实现
- 每个 Checkpoint 停下来独立验证该用户故事
- 每个任务或逻辑组完成后提交
