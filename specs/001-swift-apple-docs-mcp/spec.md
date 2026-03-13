# Feature Specification: Swift 原生 Apple 文档 MCP 服务器

**Feature Branch**: `001-swift-apple-docs-mcp`
**Created**: 2026-03-12
**Status**: Completed
**Input**: User description: "用 Swift 构建一个'终极版'Apple 文档 MCP 服务器，集三者之长、补三者之短，并利用 Swift 独有能力直接访问 Xcode 本地文档。"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 搜索 Apple 文档 (Priority: P1) 🎯 MVP

AI 编码助手在帮助开发者编写代码时，需要快速查询 Apple 官方文档中的 API 信息。助手向 MCP 服务器发起搜索请求，服务器优先从本地已下载的 Xcode 文档中查找匹配结果，若本地无结果则自动回落到在线 API 搜索，最终返回结构化的搜索结果列表。

**Why this priority**: 搜索是所有文档工具的入口操作，是 AI 助手使用最频繁的功能。没有搜索能力，其他功能无法有效发挥作用。

**Independent Test**: 可通过发送一个搜索关键词（如 "SwiftUI View"）并验证返回的搜索结果列表来独立测试。

**Acceptance Scenarios**:

1. **Given** 用户本地已安装 Xcode 并下载了文档, **When** AI 助手搜索 "UIViewController", **Then** 服务器优先返回本地文档中的匹配结果，响应包含标题、摘要和文档路径
2. **Given** 用户本地无 Xcode 文档, **When** AI 助手搜索 "SwiftUI View", **Then** 服务器自动回落到在线 API 搜索并返回结果，用户无感知错误
3. **Given** 搜索关键词支持通配符, **When** AI 助手搜索 "NS*Controller", **Then** 服务器返回所有匹配的控制器类文档
4. **Given** 首次在线搜索完成, **When** 相同关键词再次搜索, **Then** 服务器从本地缓存返回结果，缓存命中响应时间较首次在线获取 ≥10 倍加速 (SC-008)

---

### User Story 2 - 获取完整文档内容 (Priority: P1)

AI 助手确定了目标 API 后，需要获取其完整文档内容以理解参数、返回值、使用示例等细节。服务器将 Apple DocC 格式的文档转换为高质量的 Markdown 格式返回，包括所有代码示例、注意事项（aside/callout）、表格等结构化内容。

**Why this priority**: 获取文档内容是搜索之后的核心操作，AI 助手需要完整的文档信息才能准确辅助编码。低质量的渲染（如仅返回标题和摘要）会严重降低 AI 的辅助效果。

**Independent Test**: 可通过请求一个已知文档路径（如 SwiftUI 的 View 协议）并验证返回的完整 Markdown 内容来测试。

**Acceptance Scenarios**:

1. **Given** 一个有效的文档路径, **When** AI 助手请求获取文档, **Then** 返回完整的 Markdown 格式文档，包含参数说明、返回值、代码示例、注意事项
2. **Given** 文档包含 aside/callout/table 等复杂结构, **When** 渲染为 Markdown, **Then** 所有结构完整保留，格式正确可读
3. **Given** 文档路径指向本地已缓存内容, **When** 请求获取, **Then** 直接从缓存返回而非发起网络请求
4. **Given** 无效的文档路径, **When** 请求获取, **Then** 返回清晰的错误信息，AI 助手可理解并据此调整策略

---

### User Story 3 - 查询 Xcode 本地已下载文档 (Priority: P1)

开发者通过 Xcode 下载了特定 SDK 版本的文档。AI 助手可以直接查询这些本地文档，获取与开发者当前开发环境精确匹配的 API 信息，无需网络连接。

**Why this priority**: 这是本项目的核心差异化特性。本地文档访问确保 AI 助手提供与开发者实际使用的 SDK 版本一致的信息，避免版本不匹配导致的错误建议。

**Independent Test**: 可通过查询一个已知存在于本地 Xcode 文档缓存中的符号来独立测试。

**Acceptance Scenarios**:

1. **Given** Xcode 已安装且文档已下载, **When** AI 助手查询本地符号 "Array.append", **Then** 返回本地文档中的精确匹配结果
2. **Given** Xcode 已安装但特定 SDK 文档未下载, **When** AI 助手查询该 SDK 的符号, **Then** 告知该文档在本地不可用，并建议回落到在线查询
3. **Given** 完全离线环境, **When** AI 助手查询已下载的本地文档, **Then** 正常返回结果，功能不受影响
4. **Given** 本地索引可用, **When** 对符号进行模糊匹配搜索, **Then** 在毫秒级时间内返回匹配结果

---

### User Story 4 - 浏览 Apple 技术目录 (Priority: P2)

AI 助手需要了解 Apple 提供的技术框架全景，以便为开发者推荐合适的技术方案。服务器提供浏览 Apple 技术分类目录的能力，包括各框架的概述信息。

**Why this priority**: 技术目录浏览帮助 AI 助手在不确定具体 API 时进行探索性查询，但频率低于直接搜索和文档获取。

**Independent Test**: 可通过请求技术目录并验证返回的分类列表来测试。

**Acceptance Scenarios**:

1. **Given** 无任何前置操作, **When** AI 助手请求浏览技术目录, **Then** 返回完整的 Apple 技术框架分类列表
2. **Given** 技术目录已被缓存, **When** 再次请求浏览, **Then** 从缓存返回结果，无需网络请求

---

### User Story 5 - 获取 HIG 人机界面指南 (Priority: P2)

AI 助手在帮助开发者设计 UI 时，需要参考 Apple 的人机界面指南 (HIG)。服务器提供获取 HIG 特定章节内容的能力，返回高质量 Markdown 格式。

**Why this priority**: HIG 是 UI 设计的重要参考，但使用频率低于 API 文档查询。

**Independent Test**: 可通过请求 HIG 中的特定主题（如 "Navigation"）并验证返回内容来测试。

**Acceptance Scenarios**:

1. **Given** 一个有效的 HIG 主题, **When** AI 助手请求获取, **Then** 返回完整的 Markdown 格式 HIG 内容
2. **Given** 无效的 HIG 主题, **When** 请求获取, **Then** 返回清晰的错误提示

---

### User Story 6 - 获取第三方 Swift-DocC 文档 (Priority: P2)

AI 助手需要查询第三方 Swift 包的文档（如 Alamofire、SnapKit 等），这些文档以 Swift-DocC 格式托管在不同的服务器上。

**Why this priority**: 第三方库文档是开发中的常见需求，但属于核心 Apple 文档能力的扩展。

**Independent Test**: 可通过请求一个已知的第三方 DocC 文档 URL 并验证返回内容来测试。

**Acceptance Scenarios**:

1. **Given** 一个有效的第三方 DocC 文档 URL, **When** AI 助手请求获取, **Then** 返回完整的 Markdown 格式文档
2. **Given** 第三方服务不可用, **When** 请求获取, **Then** 返回明确的错误信息而非挂起

---

### User Story 7 - 获取 WWDC 视频转录 (Priority: P3)

AI 助手在帮助开发者理解新技术或排查问题时，可能需要参考 WWDC 会议视频的文字转录内容。

**Why this priority**: WWDC 转录是有价值的补充信息来源，但使用频率最低，且内容不如 API 文档精确。

**Independent Test**: 可通过请求一个已知的 WWDC 视频 ID 并验证返回的转录内容来测试。

**Acceptance Scenarios**:

1. **Given** 一个有效的 WWDC 视频标识, **When** AI 助手请求获取转录, **Then** 返回视频的文字转录内容
2. **Given** 视频无转录内容, **When** 请求获取, **Then** 返回明确的"无可用转录"信息
3. **Given** 首次获取转录完成, **When** 再次请求同一视频, **Then** 从缓存返回而非重新下载

---

### User Story 8 - 双模式连接 (Priority: P2)

MCP 服务器支持两种连接模式。默认的标准输入/输出模式适合本地 IDE 集成（如 Claude Desktop、Cursor），零网络开销；进阶的 HTTP 模式支持远程 AI Agent 通过网络调用，自带会话管理和流式推送能力。

**Why this priority**: 默认模式已覆盖最常见场景，HTTP 模式面向进阶用户和分布式部署，优先级低于核心文档功能。

**Independent Test**: 可通过分别以两种模式启动服务器并发送工具调用请求来测试。

**Acceptance Scenarios**:

1. **Given** 以标准输入/输出模式启动, **When** 通过 stdin 发送请求, **Then** 通过 stdout 返回结果，无网络开销
2. **Given** 以 HTTP 模式启动, **When** 通过 HTTP 发送请求, **Then** 正确建立会话并通过流式推送返回结果
3. **Given** 客户端配置中未指定模式, **When** 启动服务器, **Then** 默认使用标准输入/输出模式

---

### Edge Cases

- 当 Apple 在线 API 返回 403/429 错误（请求被拒或限速）时，系统如何处理？
- 当本地 Xcode 文档缓存损坏或格式不兼容时，系统如何降级？
- 当缓存过期但网络不可用时，是否仍返回过期数据？
- 当多个 AI Agent 同时通过 HTTP 模式连接时，会话管理是否正确隔离？
- 当文档内容过大超出 AI 上下文窗口时，如何处理？

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系统 MUST 提供文档搜索能力，支持关键词搜索和通配符匹配（`*`、`?`）
- **FR-002**: 系统 MUST 实现三层数据回落逻辑：本地 Xcode 文档 → 磁盘缓存 → 在线 API
- **FR-003**: 系统 MUST 将 Apple DocC 格式文档转换为高质量 Markdown，完整保留代码示例、aside/callout、表格等结构
- **FR-004**: 系统 MUST 读取用户本地 Xcode 已下载的文档缓存
- **FR-005**: 系统 MUST 提供本地文档索引的符号定位能力，p95 ≤ 100ms (SC-002)
- **FR-006**: 系统 MUST 支持本地 Spotlight 搜索用于全量模糊匹配
- **FR-007**: 系统 MUST 提供 7 个精简的 MCP 工具，每个工具独立可用、无状态 *(注：US-8 双模式连接是传输层配置，非独立工具)*
- **FR-008**: 系统 MUST 实现磁盘持久化缓存，支持 TTL 过期管理
- **FR-009**: 系统 MUST 支持内存级 LRU 缓存以加速高频查询，容量可配置（默认 100 条目），采用 LRU 淘汰策略，满容量时自动淘汰最久未访问条目
- **FR-010**: 系统 MUST 支持通过标准输入/输出方式连接本地 IDE
- **FR-011**: 系统 MUST 支持通过 HTTP 方式连接远程 AI Agent，包含会话管理和流式推送
- **FR-012**: 系统 MUST 实现优雅关闭，确保缓存写入完成后再退出进程
- **FR-013**: 系统 MUST 输出分级结构化日志（debug / info / warning / error）
- **FR-014**: 系统 MUST 通过 MCP 协议向客户端推送关键运行时日志
- **FR-015**: 系统 MUST 在 API 返回 403/429 时自动切换请求标识重试，最大重试 3 次，采用指数退避策略（1s → 2s → 4s），单次请求超时 10s
- **FR-016**: 系统 MUST 在本地文档不可用时静默回落到在线 API（不向用户报错），但 MUST 记录 warning 级别日志以满足可观测性要求 (Constitution IV)
- **FR-017**: 系统 MUST 所有错误返回语义化信息，AI 助手可理解并据此调整策略
- **FR-018**: 系统 MUST 编译为单一可执行文件，零外部运行时依赖
- **FR-019**: 系统 MUST 支持获取 Apple HIG 人机界面指南内容
- **FR-020**: 系统 MUST 支持获取第三方 Swift-DocC 格式文档
- **FR-021**: 系统 MUST 支持获取 WWDC 视频文字转录内容
- **FR-022**: 系统 MUST 对大文件（如索引文件 >5MB）使用内存映射技术以降低系统资源消耗
- **FR-023**: 系统 MUST 支持浏览 Apple 技术框架分类目录
- **FR-024**: 系统 MUST 在文档内容渲染后体积过大（>100KB 或预估 Token >20k）时，自动截断非核心代码示例并追加截断提示，以防止超出 AI 助手上下文窗口

### Key Entities *(include if feature involves data)*

- **文档条目 (Documentation Entry)**: 代表一份 Apple 官方文档内容，包含标题、摘要、完整内容、所属框架、适用平台和 SDK 版本等属性
- **搜索结果 (Search Result)**: 代表一次搜索操作的匹配结果，包含标题、摘要、文档路径、匹配度和来源层级（本地/缓存/在线）
- **缓存条目 (Cache Entry)**: 代表一条被持久化的数据，包含原始内容、创建时间、过期时间 (TTL)、数据来源
- **Xcode 本地文档 (Xcode Local Documentation)**: 代表用户通过 Xcode 下载的本地文档集合，包含 SDK 版本、平台类型、文档路径、索引信息
- **MCP 工具 (MCP Tool)**: 代表服务器暴露的一个可调用工具，包含工具名称、描述、输入参数定义、输出格式
- **技术框架 (Technology)**: 代表 Apple 技术目录中的一个框架，包含名称、描述、所属分类、文档入口路径
- **HIG 条目 (HIG Entry)**: 代表人机界面指南中的一个主题，包含标题、内容、适用平台
- **视频转录 (Video Transcript)**: 代表一个 WWDC 视频的文字转录，包含视频标识、标题、年份、转录文本

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: AI 助手可在 2 秒内完成一次文档搜索并获得结果（本地文档场景）
- **SC-002**: 本地索引符号定位在 100 毫秒内返回结果
- **SC-003**: 渲染后的 Markdown 文档完整保留原始文档中 100% 的语义结构（代码块、表格、callout、aside 等）
- **SC-004**: 在离线环境下，所有已缓存和已下载的本地文档功能 100% 可用
- **SC-005**: 服务器可执行文件体积不超过 20MB，无需安装任何外部运行时
- **SC-006**: 在线 API 被限速时，自动重试成功率达到 90% 以上
- **SC-007**: 7 个 MCP 工具中，任意单个工具均可独立调用成功，无需前置步骤
- **SC-008**: 缓存命中时的文档获取速度比在线获取快 10 倍以上
- **SC-009**: 进程收到终止信号后在 5 秒内完成优雅关闭
- **SC-010**: 所有关键操作（文档发现、缓存命中/未中、API 回落、错误降级）均有结构化日志输出
