<!--
## 同步影响报告 (Sync Impact Report)

- **版本变更**: 0.0.0 → 1.0.0 (首次制定)
- **新增原则**:
  - I. 离线优先 (Offline-First)
  - II. 无状态工具设计 (Stateless Tool Design)
  - III. 测试先行 (Test-First)
  - IV. 可观测性 (Observability)
  - V. 极简主义 (Simplicity)
  - VI. Swift 原生优先 (Native Swift First)
  - VII. 类型安全 (Type Safety)
- **新增章节**:
  - 技术约束 (Technical Constraints)
  - 开发工作流 (Development Workflow)
  - Governance
- **模板同步状态**:
  - `.specify/templates/plan-template.md` — ✅ Constitution Check 章节已与原则对齐
  - `.specify/templates/spec-template.md` — ✅ 需求/场景模板可兼容当前原则
  - `.specify/templates/tasks-template.md` — ✅ 任务分类与原则驱动的任务类型一致
- **待办事项**: 无
-->

# iDocs-MCP Constitution

## Core Principles

**注意**: 所有回答请用中文

### I. 离线优先 (Offline-First)

数据获取 **必须 (MUST)** 遵循三层优先级逻辑，确保在无网络环境下仍能提供核心价值：

1. **Local Xcode Layer**: 优先返回 `~/Library/Developer/Xcode/DocumentationCache` 中已下载的本地文档
2. **Disk Cache Layer**: 检查 `~/Library/Caches/` 下的持久化缓存（含 TTL 过期管理）
3. **Remote API Layer**: 仅在前两层未命中时回落至网络请求，并静默更新本地缓存

**理由**: AI 编码助手的响应速度直接影响开发体验。本地优先策略消除网络延迟、保障隐私，并确保离线环境下的可用性。

### II. 无状态工具设计 (Stateless Tool Design)

每个 MCP 工具 **必须 (MUST)** 独立可用，**禁止 (MUST NOT)** 要求前置步骤或会话状态：

- 工具之间不存在调用顺序依赖
- 每次工具调用包含完整的输入参数，不依赖前次调用的上下文
- AI Agent 可直接调用任意工具，无需"先选择技术"等前置操作

**理由**: 有状态工作流（如必须先调用 `choose_technology`）会降低 AI 的工具选择效率，增加不必要的交互轮次。

### III. 测试先行 (Test-First)

所有功能实现 **必须 (MUST)** 遵循 TDD 流程：

- 先编写测试 → 确认测试失败（Red） → 实现功能（Green） → 重构（Refactor）
- 使用 Swift Testing 框架编写单元测试
- 集成测试覆盖：Xcode 本地文档读取、Apple API 请求、缓存层行为
- 执行命令：`swift test`（单元测试）、`swift test --filter IntegrationTests`（集成测试）

**理由**: 对于涉及多数据源回落和缓存层级的系统，测试是保障正确性的关键基础设施。

### IV. 可观测性 (Observability)

所有运行时行为 **必须 (MUST)** 通过结构化日志可追踪：

- 基于 `swift-log` 输出分级日志（debug / info / warning / error）
- 通过 MCP 协议内置 `server.log()` 向客户端推送关键事件
- **必须 (MUST)** 记录的事件：Xcode 本地文档发现、缓存命中/未中、API 回落、错误降级

**理由**: MCP Server 在 AI Agent 与数据源之间扮演中间层角色，缺乏可观测性将导致问题难以定位。

### V. 极简主义 (Simplicity)

设计决策 **必须 (MUST)** 遵循 YAGNI 原则：

- MCP 工具数量控制在 7 个，每个工具职责清晰、不重叠
- 不内嵌大体积数据（如 35MB WWDC 转录），改为按需在线获取 + 本地缓存
- 编译为单二进制文件，零外部运行时依赖（无 Node.js / Python）
- 复杂度必须被证明合理，否则选择更简单的方案

**理由**: 工具数量过多（如 15 个）会导致 AI 选择困难，包体积过大会影响分发效率。

### VI. Swift 原生优先 (Native Swift First)

技术选型 **必须 (MUST)** 优先使用 Swift 和 macOS 原生能力：

- Swift MCP SDK (`modelcontextprotocol/swift-sdk`) 内置 Transport，**禁止 (MUST NOT)** 引入额外 Web 框架
- 使用 `Foundation.FileManager` + `Data(contentsOf:options:.mappedIfSafe)` 进行文件 I/O
- 使用 `NSMetadataQuery` (Spotlight) 进行本地文档搜索
- 使用 `Process` (Foundation) 调用 `xcrun docc` 工具链
- 使用 C 桥接直读 LMDB 索引

**理由**: 这些是 Swift/macOS 的独有能力，是本项目相对于 Node.js/Python 竞品的核心差异化优势。

### VII. 类型安全 (Type Safety)

数据建模 **必须 (MUST)** 利用 Swift 编译期类型系统：

- 所有 DocC JSON 结构通过 `Codable` 协议进行强类型解析
- **禁止 (MUST NOT)** 在数据解析代码中使用 `any` / `AnyObject` 等擦除类型
- 错误通过 `MCPError` 类型返回语义化信息，确保 AI 可理解

**理由**: TypeScript 的 `any` 只在运行时暴露问题，Swift 的 `Codable` 在编译期保证正确性。

## 技术约束 (Technical Constraints)

- **语言版本**: Swift 6.2+，启用 Structured Concurrency (`async/await` + `TaskGroup` + `Actor`)
- **包管理**: Swift Package Manager (SPM) 负责依赖声明 + Tuist 负责 Xcode 工程生成与编译缓存
- **核心依赖**:
  | 依赖 | 版本 | 用途 |
  |------|------|------|
  | `modelcontextprotocol/swift-sdk` | v0.11.0+ | MCP 协议 + Transport |
  | `swift-server/swift-service-lifecycle` | v2.3.0+ | 优雅关闭 (Graceful Shutdown) |
  | `apple/swift-log` | latest | 结构化日志 |
- **传输模式**: `StdioTransport`（默认，本地 IDE）+ `StatefulHTTPServerTransport`（进阶，远程 Agent）
- **目标平台**: macOS（利用 Xcode 本地文档和 Spotlight 等系统级能力）
- **编译产物**: 静态链接 Mach-O 二进制，零外部运行时依赖
- **开发 Skills**: Swift Concurrency → `swift-concurrency-expert`；Testing → `swift-testing-expert`

## 开发工作流 (Development Workflow)

- **Constitution 合规**: 所有 PR/代码审查 **必须 (MUST)** 验证是否符合 Core Principles
- **测试门禁**: 功能合并前 **必须 (MUST)** 通过 `swift test` 全量测试
- **代码审查清单**:
  - 是否遵循离线优先的三层数据回落逻辑？
  - 新增工具是否保持无状态？
  - 是否存在不必要的 `any` 类型？
  - 关键事件是否有结构化日志？
  - 错误处理是否优雅降级而非直接失败？
- **版本管理**: 遵循语义化版本 (SemVer)
- **提交规范**: 使用 Conventional Commits 格式

## Governance

本 Constitution 是 iDocs-MCP 项目所有开发实践的最高准则。

- **优先级**: Constitution 的规定优先于项目中任何其他文档或实践
- **修订程序**: 任何修订 **必须 (MUST)** 提供：变更说明、影响分析、迁移方案
- **版本策略**:
  - MAJOR: 原则删除或不兼容的重新定义
  - MINOR: 新增原则/章节或实质性扩展
  - PATCH: 措辞澄清、错别字修正、非语义性优化
- **合规检查**: 每个 Plan 阶段 **必须 (MUST)** 执行 Constitution Check 以验证设计决策符合原则

**Version**: 1.0.0 | **Ratified**: 2026-03-12 | **Last Amended**: 2026-03-12
