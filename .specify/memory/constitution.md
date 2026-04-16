<!--
## 同步影响报告 (Sync Impact Report)

- **版本变更**: 1.1.0 → 2.0.0 (CLI-only 方向收口)
- **新增原则**: 无
- **修改原则**:
  - II. 无状态命令与适配层设计 (由 MCP 工具设计改为 CLI-only 运行时边界)
  - IV. 可观测性 (移除 MCP `server.log()` 依赖)
  - V. 极简主义 (由 7 个 MCP 工具改为聚焦 CLI 命令面)
  - VI. Swift 原生优先 (移除 MCP SDK / Transport 作为主产品依赖)
  - VII. 类型安全 (错误契约由 `MCPError` 调整为 CLI/Adapter 语义错误)
- **新增章节**:
  - 无
- **模板同步状态**:
  - `.specify/templates/plan-template.md` — ✅ Constitution Check 章节已与原则对齐
  - `.specify/templates/spec-template.md` — ✅ 需求/场景模板可兼容当前原则
  - `.specify/templates/tasks-template.md` — ✅ 任务分类与原则驱动的任务类型一致
- **待办事项**: 无
-->

# iDocs Constitution

## Core Principles

**注意**: 所有回答请用中文

### I. 离线优先 (Offline-First)

数据获取 **必须 (MUST)** 采用确定性的本地优先链路，确保在无网络环境下仍能提供核心价值：

1. `search` **必须 (MUST)** 优先检查内存缓存，再查本地 Xcode 文档，最后按 `apple -> sosumi` 固定顺序回落远端
2. `fetch` **必须 (MUST)** 优先检查磁盘缓存，再查本地 Xcode 文档，最后按 `apple -> sosumi` 固定顺序回落远端
3. `list` **必须 (MUST)** 保持显式数据源与稳定输出契约，不得隐式恢复历史 MCP 会话语义

**理由**: AI 编码助手的响应速度直接影响开发体验。本地优先策略消除网络延迟、保障隐私，并确保离线环境下的可用性。

### II. 无状态命令与适配层设计 (Stateless CLI/Adapter Design)

CLI 命令与 Adapter API **必须 (MUST)** 独立可用，**禁止 (MUST NOT)** 要求前置步骤或会话状态：

- 命令之间不存在调用顺序依赖
- 每次调用都必须携带完整输入，不依赖前次请求上下文
- 主产品运行时 **禁止 (MUST NOT)** 恢复 MCP transport、会话管理或“先选择技术”式前置交互
- 项目内 benchmark 用到的 MCP 配置 **必须 (MUST)** 与主产品运行时隔离，仅作为对比环境资产存在

**理由**: 主产品已经收敛为 CLI-only。把历史 MCP 交互模型重新混入运行时，只会增加状态复杂度和使用成本。

### III. 测试先行 (Test-First)

所有功能实现 **必须 (MUST)** 遵循 TDD 流程：

- 先编写测试 → 确认测试失败（Red） → 实现功能（Green） → 重构（Refactor）
- 使用 Swift Testing 框架编写单元测试
- 默认验证 **必须 (MUST)** 覆盖所有一等产品测试目标（当前至少包括 `iDocsTests` 与 `iDocsAdapterTests`）
- 网络集成测试只在显式启用时运行，避免把外部服务波动伪装成默认质量门禁

**理由**: 对于涉及多数据源回落和缓存层级的系统，测试是保障正确性的关键基础设施。

### IV. 可观测性 (Observability)

所有运行时行为 **必须 (MUST)** 通过结构化日志可追踪：

- 基于 `swift-log` 或 Adapter 注入的 `DocumentationLogger` 输出分级日志（debug / info / warning / error）
- CLI 成功输出 **必须 (MUST)** 暴露来源标记（如 `cache` / `local` / `apple` / `sosumi`），便于问题定位
- **必须 (MUST)** 记录的事件：Xcode 本地文档发现、缓存命中/未中、远端回落、错误降级

**理由**: CLI 是当前唯一主产品入口。缺乏可观测性会直接放大多源回落链路中的定位成本。

### V. 极简主义 (Simplicity)

设计决策 **必须 (MUST)** 遵循 YAGNI 原则：

- 主产品命令面保持聚焦，当前以 `search`、`fetch`、`list` 为核心；新增命令必须能证明其必要性
- 不内嵌大体积数据（如 35MB WWDC 转录），改为按需在线获取 + 本地缓存
- 编译为单 CLI 二进制文件，零外部运行时依赖（无 Node.js / Python）
- benchmark、分发和对比资产不得反向污染主产品运行时复杂度
- 复杂度必须被证明合理，否则选择更简单的方案

**理由**: 当前产品价值在于稳定 CLI 契约和可预测的多源检索，而不是恢复更复杂的历史运行时。

### VI. Swift 原生优先 (Native Swift First)

技术选型 **必须 (MUST)** 优先使用 Swift 和 macOS 原生能力：

- 使用 `Foundation.FileManager` + `Data(contentsOf:options:.mappedIfSafe)` 进行文件 I/O
- 使用 `URLSession` / `URLRequest` 进行远端抓取与重试控制
- 使用 Spotlight/本地索引能力进行本地文档搜索
- 使用 `Process` (Foundation) 调用 `xcrun docc` 工具链
- 使用 Swift 并发原语（`async/await`、`actor`）封装缓存与远端访问
- 主产品运行时 **禁止 (MUST NOT)** 重新引入 MCP SDK、HTTP transport server 或额外 Web 框架

**理由**: Swift/macOS 的本地文档访问与并发能力，才是 CLI-only 产品线的核心差异化优势。

### VII. 类型安全 (Type Safety)

数据建模 **必须 (MUST)** 利用 Swift 编译期类型系统：

- 所有 DocC JSON 结构通过 `Codable` 协议进行强类型解析
- **禁止 (MUST NOT)** 在数据解析代码中使用 `any` / `AnyObject` 等擦除类型
- 错误通过 `DocumentationError`、`iDocsError` 或等价语义错误返回，确保 CLI 与测试都能稳定理解

**理由**: TypeScript 的 `any` 只在运行时暴露问题，Swift 的 `Codable` 在编译期保证正确性。

### VIII. Agent 记忆边界 (Agent Memory Boundary)

所有规则根据类型严格划分存储边界，禁止 (MUST NOT) 越界：

- **架构规则 (Architecture)**：设计决策、状态管理、领域逻辑，必须独立存放在 Constitution 中。
- **基础设施 (Infrastructure)**：构建命令、测试脚本、Git 工作流，必须存放在 `AGENTS.md`（或 `GEMINI.md`）中。

**理由**：保持 `AGENTS.md` 简洁以降低每次会话的 token 消耗，同时通过 Constitution 集中管理核心架构原则，借助 `memorylint` 技能定期强制执行边界审计。

## 技术约束 (Technical Constraints)

- **语言版本**: Swift 6.x，使用 Structured Concurrency（`async/await` + `actor`）实现并发访问
- **包管理**: Swift Package Manager (SPM) 负责依赖声明 + Tuist 负责 Xcode 工程生成与编译缓存
- **核心依赖**:
  | 依赖 | 版本 | 用途 |
  |------|------|------|
  | `apple/swift-log` | latest | 结构化日志 |
  | `apple/swift-argument-parser` | latest | CLI 命令面 |
- **远端源**: Apple 官方文档端点为主，`sosumi.ai` 作为固定回落源
- **目标平台**: macOS（利用 Xcode 本地文档和 Spotlight 等系统级能力）
- **编译产物**: `idocs` CLI 二进制 + npm wrapper；项目级 MCP 配置仅用于 benchmark 资产，不属于主产品运行时
- **开发 Skills**: Swift Concurrency → `swift-concurrency-expert`；Testing → `swift-testing-expert`

## 开发工作流 (Development Workflow)

- **Constitution 合规**: 所有 PR/代码审查 **必须 (MUST)** 验证是否符合 Core Principles
- **测试门禁**: 功能合并前 **必须 (MUST)** 通过架构门禁和默认完整测试套件
- **代码审查清单**:
  - 是否遵循离线优先的确定性回落逻辑？
  - CLI/Application 层是否仍通过 Adapter 访问核心能力？
  - benchmark MCP 资产是否仍与主产品运行时隔离？
  - 是否存在不必要的 `any` 类型？
  - 关键事件是否有结构化日志？
  - 错误处理是否优雅降级而非直接失败？
- **版本管理**: 遵循语义化版本 (SemVer)
- **提交规范**: 使用 Conventional Commits 格式

## Governance

本 Constitution 是 iDocs 项目所有开发实践的最高准则。

- **优先级**: Constitution 的规定优先于项目中任何其他文档或实践
- **修订程序**: 任何修订 **必须 (MUST)** 提供：变更说明、影响分析、迁移方案
- **版本策略**:
  - MAJOR: 原则删除或不兼容的重新定义
  - MINOR: 新增原则/章节或实质性扩展
  - PATCH: 措辞澄清、错别字修正、非语义性优化
- **合规检查**: 每个 Plan 阶段 **必须 (MUST)** 执行 Constitution Check 以验证设计决策符合原则

**Version**: 2.0.0 | **Ratified**: 2026-03-12 | **Last Amended**: 2026-04-15
