# Implementation Plan: Swift 原生 Apple 文档 MCP 服务器

> Historical note: 本计划对应的 MCP Server 方向已被 CLI-only 主线替代。当前产品/runtime 以 `specs/005-three-layer-architecture/` 和 `specs/006-cli-multisource-docs/` 为准；本文件仅作为历史方案留档。

**Branch**: `001-swift-apple-docs-mcp` | **Date**: 2026-03-13 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/001-swift-apple-docs-mcp/spec.md`

## Summary

构建一个 Swift 原生的 Apple 文档 MCP 服务器 (iDocs)，综合三个现有开源项目 (apple-doc-mcp、apple-docs-mcp、sosumi.ai) 的优势，同时利用 Swift/macOS 独有的系统级能力——Xcode 本地文档直读、LMDB 索引、Spotlight 搜索——提供离线优先、无状态、高质量 Markdown 渲染的 7 工具 MCP 服务器。

## Technical Context

**Language/Version**: Swift 6.2+ (Structured Concurrency: async/await + TaskGroup + Actor)
**Primary Dependencies**:
  - `modelcontextprotocol/swift-sdk` v0.11.0+ (MCP 协议 + Transport)
  - `swift-server/swift-service-lifecycle` v2.3.0+ (优雅关闭)
  - `apple/swift-log` latest (结构化日志)
**Storage**: 文件系统 (`~/Library/Caches/iDocs/` 磁盘缓存) + 内存 LRU 缓存
**Testing**: Swift Testing framework (`swift test`)
**Target Platform**: macOS 13.0+ (利用 Xcode 文档缓存、Spotlight、xcrun docc)
**Project Type**: CLI 工具 / MCP Server (单二进制分发)
**Performance Goals**: 本地符号定位 <100ms；缓存命中文档获取 <200ms
**Constraints**: 离线优先；零外部运行时依赖；单二进制 <20MB
**Scale/Scope**: 7 个 MCP 工具；支持单用户本地 + 多 Agent 远程连接

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原则 | 状态 | 验证说明 |
|------|:---:|---------|
| I. 离线优先 | ✅ | 三层数据回落：Xcode 本地 → 磁盘缓存 → 远程 API |
| II. 无状态工具设计 | ✅ | 7 个工具均独立可用，无前置步骤依赖 |
| III. 测试先行 | ✅ | 使用 Swift Testing，TDD 流程 |
| IV. 可观测性 | ✅ | swift-log + MCP server.log() 双通道日志 |
| V. 极简主义 | ✅ | 7 个精简工具；WWDC 数据按需在线获取；单二进制分发 |
| VI. Swift 原生优先 | ✅ | SDK 内置 Transport，Foundation 文件 I/O，NSMetadataQuery，C 桥接 LMDB |
| VII. 类型安全 | ✅ | 全量 Codable 解析，禁止 any/AnyObject |

**合规技术约束**:
- ✅ Swift 6.2+
- ✅ SPM + Tuist
- ✅ 核心依赖版本符合要求

## Project Structure

### Documentation (this feature)

```text
specs/001-swift-apple-docs-mcp/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (MCP Tool schemas)
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
Sources/
└── iDocs/
    ├── iDocsServer.swift            # MCP Server 主入口 + 工具注册
    ├── Tools/
    │   ├── SearchDocsTool.swift      # search_docs: 搜索 Apple 文档
    │   ├── FetchDocTool.swift        # fetch_doc: 获取文档完整内容
    │   ├── FetchHIGTool.swift        # fetch_hig: 获取 HIG 内容
    │   ├── BrowseTechnologiesTool.swift # browse_technologies: 浏览技术目录
    │   ├── FetchExternalDocTool.swift # fetch_external_doc: 第三方 DocC
    │   ├── FetchVideoTranscriptTool.swift # fetch_video_transcript: WWDC 转录
    │   └── XcodeDocsTool.swift       # xcode_docs: Xcode 本地文档查询
    ├── DataSources/
    │   ├── AppleJSONAPI.swift        # Apple developer.apple.com JSON API 客户端
    │   ├── XcodeLocalDocs.swift      # Xcode 本地文档读取 (mmap + LMDB)
    │   ├── HIGFetcher.swift          # HIG 内容获取与解析
    │   └── ExternalDocCFetcher.swift # 第三方 DocC 站点代理
    ├── Rendering/
    │   ├── DocCRenderer.swift        # DocC JSON → Markdown 渲染器
    │   └── DocCTypes.swift           # DocC JSON Codable 类型定义
    ├── Cache/
    │   ├── DiskCache.swift           # ~/Library/Caches/iDocs/ 磁盘持久化
    │   └── MemoryCache.swift         # LRU 内存缓存 (Actor-based)
    └── Utils/
        ├── UserAgentPool.swift       # UserAgent 随机轮换池
        └── URLHelpers.swift          # URL 解析与转换工具

Tests/
└── iDocsTests/
    ├── RenderingTests.swift          # DocC 渲染器单元测试
    ├── CacheTests.swift              # 缓存层单元测试
    ├── XcodeLocalDocsTests.swift     # Xcode 本地文档集成测试
    ├── ToolTests.swift               # MCP 工具集成测试
    └── IntegrationTests/
        ├── AppleAPITests.swift       # Apple API 集成测试 (需网络)
        └── ServerTests.swift         # MCP Server 端到端测试
```

**Structure Decision**: 采用单项目结构 (Swift Package)，以 SPM 管理依赖，Tuist 管理 Xcode 工程。Sources 按职责分层：Tools → DataSources → Rendering → Cache → Utils。

## Complexity Tracking

> 无 Constitution Check 违规，无需记录。
