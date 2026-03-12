# iDocs-MCP: Swift 原生 Apple 文档 MCP 服务器

用 Swift 构建一个"终极版"Apple 文档 MCP 服务器，集三者之长、补三者之短，并利用 Swift 独有能力直接访问 Xcode 本地文档。


- `analysis_report.md` - 分析报告
- `mcp-swift-sdk.md` - MCP Swift SDK README 文档


## User  Required

> 1. **Xcode 本地文档访问**作为核心差异化特性，支持访问用户安装 Xcode 并下载的文档。如果没有安装使用网络访问.
> 2. **项目名称**建议为 `awesome-iDocs-mcp`作为空间名称，但是整个项目中使用的关键字就是iDocs就好了.
> 3. **核心SDK依赖** 按照官方 [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk?tab=readme-ov-file#transport-options-for-clients) 来构建 
> 4. 使用 Swift 6.2+
> 5. 在开发过程中使用的skills 分别对应 swift concurrency使用: swift-concurrency-expert; Testing使用: swift-test-expert .
> 6. 包管理工具使用Swift package manager + tuist .


---

## 核心特性 (Key Features)

### 1. 双模式传输 (Dual-Transport Support)
基于 Swift MCP SDK (v0.11.0+) 内置 Transport，提供无缝切换的连接方式：
- **`StdioTransport`**: 默认模式，专为本地 IDE（如 Claude Desktop, Cursor）优化，零网络开销，极致隐私。
- **`StatefulHTTPServerTransport`**: 进阶模式，SDK 内置的 HTTP Server Transport（含 SSE 流式推送 + 会话管理），支持跨设备、分布式 AI Agent 远程调用。**不需要额外 Web 框架依赖。**

### 2. 深度 Xcode 本地集成 (Native Xcode Integration)
完全利用 Swift 的系统级访问能力，突破“网络依赖”的局限：
- **Xcode 文档镜像**: 直接读取 `~/Library/Developer/Xcode/DocumentationCache` 下的 OS/SDK 版本化缓存。
- **LMDB 索引访问**: 通过原生 C 桥接读取 `data.mdb` 索引，实现毫秒级的符号定位，无需下载数据。
- **Spotlight 极速搜索**: 利用 `NSMetadataQuery` 同步查询 Xcode 文档索引，支持本地全量模糊匹配。
- **本地工具链扩展**: 支持调用 `xcrun docc` 为当前正在开发的私有项目动态生成并提供 MCP 文档服务。

### 3. "离线优先"数据分层 (Offline-First Data Layer)
AI 获信息的优先级逻辑：
1. **Local Xcode Layer**: 优先返回本地已下载的精准 SDK 参数，确保护航开发环境版本。
2. **Disk Cache Layer**: 检查本地持久化存储 (`~/Library/Caches/...`)，支持 TTL 过期管理。
3. **Remote API Layer**: 自动回落至 Apple 内部 JSON API 或 HIG/外部 DocC 地址，并静默更新本地缓存。

### 4. AI 优化的输出架构
针对 AI Agent 的上下文窗口 (Context Window) 进行极致压缩与渲染优化：
- **高保真 Markdown**: 移植并改进 `sosumi.ai` 的高阶渲染器，利用 Swift 强类型 `Codable` 确保 DocC 节点的各种 aside/callout/table 完美呈现。
- **Token 压缩策略**: [优先级低]AI 模式下自动移除文档中的“冗余元数据”（如重复的版权信息、导航页脚），确保每一条返回都具备最高信息密度, 默认不开启，用户可以开启。


### 5. 原生极速分发
- **单二进制运行**: 编译为静态链接的 Mach-O 文件，不依赖 Node.js/Python 等外部环境。
- **低内存占用**: 大文件采用 `mmap` (内存映射) 技术，索引查询对系统资源消耗极低。

### 6. Graceful Shutdown (优雅关闭)
- 基于 `swift-service-lifecycle` 管理进程生命周期，自动处理 `SIGINT`/`SIGTERM` 信号。
- 确保缓存写入完成、HTTP 连接断开后再退出进程。

### 7. 结构化日志 (Structured Logging)
- 基于 `swift-log` 输出分级日志 (debug/info/warning/error)。
- 通过 MCP 协议内置的 `server.log()` 向客户端推送日志。
- 关键事件记录：Xcode 本地文档发现、缓存命中/未中、API 回落等。

### 8. 错误处理与降级
- Apple API 返回 403/429 时自动切换 UserAgent 重试。
- Xcode 本地文档不可用时静默回落到在线 API（不报错）。
- 所有错误通过 `MCPError` 类型返回语义化信息，AI 可理解。

---

## Proposed Changes

### 工程管理
- **SPM**: 负责依赖库声明与解析 (`Package.swift`)
- **Tuist**: 负责 Xcode 工程生成 (`Project.swift`) 和编译缓存管理

### 项目结构

```
awesome-iDocs-mcp/
├── Project.swift                        # Tuist 工程描述
├── Tuist/
│   └── Config.swift
├── Package.swift                        # SPM 依赖声明
├── Sources/
│   └── iDocs/
│       ├── iDocsServer.swift            # MCP Server 主入口 + 工具注册
│       ├── Tools/
│       │   ├── SearchDocsTool.swift
│       │   ├── FetchDocTool.swift
│       │   ├── FetchHIGTool.swift
│       │   ├── BrowseTechnologiesTool.swift
│       │   ├── FetchExternalDocTool.swift
│       │   ├── FetchVideoTranscriptTool.swift
│       │   └── XcodeDocsTool.swift
│       ├── DataSources/
│       │   ├── AppleJSONAPI.swift        # developer.apple.com JSON API
│       │   ├── XcodeLocalDocs.swift      # Xcode 本地文档读取
│       │   ├── HIGFetcher.swift          # HIG 内容获取
│       │   └── ExternalDocCFetcher.swift # 第三方 DocC
│       ├── Rendering/
│       │   ├── DocCRenderer.swift        # DocC JSON → Markdown
│       │   └── DocCTypes.swift           # Codable 类型定义
│       ├── Cache/
│       │   ├── DiskCache.swift           # ~/Library/Caches/ 持久化
│       │   └── MemoryCache.swift         # LRU 内存缓存
│       └── Utils/
│           ├── UserAgentPool.swift
│           └── URLHelpers.swift
└── Tests/
    └── iDocsTests/
        ├── RenderingTests.swift
        ├── CacheTests.swift
        └── XcodeLocalDocsTests.swift
```

### SPM 核心依赖

| 依赖 | 用途 |
|------|------|
| `modelcontextprotocol/swift-sdk` (v0.11.0+) | MCP 协议 + Transport |
| `swift-server/swift-service-lifecycle` (v2.3.0+) | 优雅关闭 |
| `apple/swift-log` | 结构化日志 |

---

### “集三者之长”: 继承的优点

| 继承的优点 | 原项目 | iDocs 实现方式 |
|:---|:---|:---|
| 文件缓存持久化 | apple-doc-mcp | `DiskCache.swift` → `~/Library/Caches/` + TTL 过期 |
| 通配符搜索 | apple-doc-mcp | `SearchDocsTool.swift` 支持 `*`, `?` 模式 |
| 无状态工具设计 | apple-docs-mcp | 每个 Tool 独立可用，无前置步骤 |
| 全站搜索 | apple-docs-mcp | Apple 搜索 API + HTML 解析 |
| Technology 浏览 | apple-docs-mcp | `BrowseTechnologiesTool.swift` |
| TTL 分级缓存 | apple-docs-mcp | 不同数据类型不同过期时间 |
| UserAgent 池 | apple-docs-mcp | `UserAgentPool.swift` 随机轮换 |
| 高质量 Markdown 渲染 | sosumi.ai | 移植 740 行渲染器至 Swift `DocCRenderer.swift` |
| HIG 人机界面指南 | sosumi.ai | `FetchHIGTool.swift` + `HIGFetcher.swift` |
| 外部 Swift-DocC 代理 | sosumi.ai | `FetchExternalDocTool.swift` |
| WWDC 视频转录 | 两者 | 在线抓取（不内嵌 35MB 数据） |
| robots.txt + 限速合规 | sosumi.ai | 移植合规处理逻辑 |

---

### “补三者之短”: 优化的缺点

| 原项目缺点 | 出处 | iDocs 优化方案 |
|:---|:---|:---|
| 渲染质量差，仅输出标题/摘要 | apple-doc-mcp | 采用 sosumi.ai 级别的完整 Markdown 渲染器 |
| **有状态工作流**，必须先 `choose_technology` | apple-doc-mcp | 全部无状态，每个工具直接可用 |
| 单一 User-Agent，容易被封 | apple-doc-mcp | UserAgent 池随机轮换 + 403 自动重试 |
| 无缓存过期，数据可能过时 | apple-doc-mcp | TTL 分级过期 + 下次访问时静默更新 |
| 纯内存缓存，**重启后清空** | apple-docs-mcp | 磁盘缓存 (`~/Library/Caches/`) 持久化 |
| 内置 35MB WWDC 数据，**包体积巨大** | apple-docs-mcp | 改为在线按需抓取 + 本地缓存，二进制体积极小 |
| 代码中大量 `any` 类型，类型安全差 | apple-docs-mcp | Swift `Codable` 强类型解析，编译期保证 |
| 15 个工具造成 AI 选择困难 | apple-docs-mcp | 精简为 7 个，职责清晰 |
| 无应用层缓存，依赖 CDN | sosumi.ai | 本地磁盘 + 内存双层缓存 |
| 不支持 Technology 浏览/符号搜索 | sosumi.ai | `browse_technologies` + `search_docs` 工具 |
| MCP 工具仅 4 个，功能较少 | sosumi.ai | 扩展到 7 个，覆盖全场景 |
| 所有项目无结构化日志 | 三者共有 | `swift-log` + MCP `server.log()` 分级推送 |
| Bus Factor = 1，无测试覆盖 | apple-doc-mcp | Swift Testing 单元测试 + 集成测试 |

---

### “macOS/Swift 独有能力”: 三者都做不到的事

| 独有能力 | macOS/Swift 技术基础 | 为什么其他语言难健壮实现 |
|:---|:---|:---|
| **Xcode 本地文档直读** | `FileManager` + `Data(contentsOf:options:.mappedIfSafe)` | Node.js 可读文件但无法 mmap，大文件性能差 |
| **LMDB 索引原生访问** | C 桥接直读 `data.mdb` | Node.js 需 `lmdb` npm 包，编译原生模块常出问题 |
| **Spotlight 搜索** | `NSMetadataQuery` 原生 API | Node.js 只能 shell 调用 `mdfind`，无实时通知 |
| **`xcrun docc` 工具链** | `Process` (Foundation) 原生调用 | 其他语言也可 subprocess，但 Swift 可类型安全解析输出 |
| **单二进制零依赖分发** | `swift build -c release` → Mach-O | Node.js 必须带 runtime + node_modules |
| **内存映射 (mmap)** | `Data(contentsOf:options:.mappedIfSafe)` | Node.js 无原生 mmap，Python 有但性能不佳 |
| **ARC 内存管理** | 编译期确定释放点，无 GC 暂停 | Node.js V8 GC 可能导致偶发卡顿 |
| **Structured Concurrency** | `async/await` + `TaskGroup` + Actor | Node.js 单线程 event loop，复杂并发困难 |
| **Codable 强类型** | 编译期类型检查，无 `any` | TypeScript 的 `any` 在运行时才暴露问题 |
| **SDK 内置 Transport** | `StdioTransport` + `StatefulHTTPServerTransport` | Node.js 需额外 express/hono 等框架 |

---

### MCP 工具设计（7 个工具，精简高效）

| 工具名 | 描述 | 灵感来源 |
|--------|------|----------|
| `search_docs` | 搜索 Apple 文档（先本地索引 → 后在线） | apple-docs-mcp + Xcode |
| `fetch_doc` | 获取文档内容，返回完整 Markdown | sosumi.ai 渲染质量 |
| `fetch_hig` | 获取 HIG 人机界面规范 | sosumi.ai |
| `browse_technologies` | 浏览 Apple 技术目录 | apple-docs-mcp |
| `fetch_external_doc` | 获取第三方 Swift-DocC 文档 | sosumi.ai |
| `fetch_video_transcript` | 获取 WWDC 视频转录 | Both |
| `xcode_docs` | ⭐ 查询 Xcode 本地已下载文档 | 独创 |

**设计原则**（吸取教训）：
- ✅ **无状态**（不要求 `choose_technology` 等前置步骤）
- ✅ **每个工具独立可用**（不像 apple-doc-mcp 需要串联）
- ✅ **输出完整 Markdown**（不像 apple-doc-mcp 输出简陋列表）
- ✅ **工具数量适中**（7 个，不像 apple-docs-mcp 的 15 个造成选择困难）



---

## Verification Plan

### Automated Tests

由于这是新项目的规划阶段，以下是计划中的验证方式：

1. **单元测试** (Swift Testing / XCTest)
   - DocC JSON → Markdown 渲染器：对比输入 JSON 和预期 Markdown 输出
   - 缓存层：TTL 过期、LRU 淘汰
   - URL 解析和转换
   - 命令: `swift test`

2. **集成测试**
   - Xcode 本地文档读取：检测 `~/Library/Developer/Xcode/DocumentationCache` 是否存在并可读
   - Apple JSON API 实际请求（需网络）
   - 命令: `swift test --filter IntegrationTests`

### Manual Verification

3. **MCP Inspector 测试**
   - 使用 `npx @modelcontextprotocol/inspector` 连接到编译后的二进制
   - 逐个调用 7 个工具，验证返回结果格式
   - 特别验证 `xcode_docs` 工具是否能读取本地文档

4. **AI 客户端测试**
   - 配置到 Claude Desktop / Cursor 中，实际对话验证
   - 验证场景: "查询 SwiftUI 的 View 协议文档"
