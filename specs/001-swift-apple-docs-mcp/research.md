# Research: Swift 原生 Apple 文档 MCP 服务器

**Branch**: `001-swift-apple-docs-mcp` | **Date**: 2026-03-13

## 1. MCP Swift SDK Server API 模式

**Decision**: 使用 `Server` + `withMethodHandler` 模式注册工具，`StdioTransport` 作为默认传输层。

**Rationale**:
- MCP Swift SDK v0.11.0+ 提供 `Server` 类，通过 `withMethodHandler(ListTools.self)` 和 `withMethodHandler(CallTool.self)` 注册工具列表和调用处理器
- `Tool` 结构体定义工具的名称、描述和 `inputSchema`（JSON Schema 格式）
- 工具返回 `CallTool.Result`，包含 `content: [Tool.Content]` 和 `isError: Bool`
- `server.log(level:logger:data:)` 用于向客户端推送日志

**Alternatives Considered**:
- 自定义 Transport 协议：不必要，SDK 内置的 `StdioTransport` 和 `StatefulHTTPServerTransport` 已满足需求
- 使用第三方 Web 框架（Vapor/Hono）处理 HTTP：Constitution VI 明确禁止，SDK 内置 HTTP Server Transport 已足够

## 2. Xcode 本地文档访问路径

**Decision**: 读取 `~/Library/Developer/Xcode/DocumentationCache/` 下的版本化文档缓存。

**Rationale**:
- Xcode 用户通过 Preferences → Components 下载的文档存储在 `~/Library/Developer/Xcode/DocumentationCache/`
- 文档以 DocC Archive 格式组织，包含 `data.mdb` (LMDB 索引) 和 JSON 数据文件
- 使用 `Data(contentsOf:options:.mappedIfSafe)` 进行内存映射读取，大文件零拷贝
- 通过 C 桥接 (`CLMDB` 模块) 直读 LMDB 索引，O(log n) 符号定位

**Alternatives Considered**:
- `xcrun docc` 命令行工具：适合为私有项目生成文档，但不适合读取已缓存的 SDK 文档
- Spotlight (`NSMetadataQuery`)：适合全量模糊搜索，作为 LMDB 精确定位的补充手段

## 3. DocC JSON → Markdown 渲染器设计

**Decision**: 移植 sosumi.ai 的 740 行渲染器逻辑至 Swift，使用 `Codable` 强类型解析。

**Rationale**:
- sosumi.ai 的渲染器质量评分 5/5（对比: apple-doc-mcp 2/5, apple-docs-mcp 3/5）
- 覆盖全部 DocC JSON 节点类型：declarations, parameters, properties, content, tables, aside, orderedList/unorderedList, codeListing, images, relationship sections, topic sections, see also
- Swift 的 `Codable` + `enum` (代数数据类型) 比 TypeScript 更适合表达 DocC JSON 的递归节点树
- 递归深度保护：content 最大 50 层，inline 最大 20 层

**Alternatives Considered**:
- apple-docs-mcp 的解析方式：大量 `any` 类型断言，类型安全差，渲染不完整
- 自行从零设计渲染器：不必要，sosumi.ai 的逻辑已经验证，移植更高效

## 4. 缓存层架构

**Decision**: 双层缓存（内存 LRU + 磁盘持久化），基于 Actor 隔离保证并发安全。

**Rationale**:
- **MemoryCache**: Actor-based LRU 缓存，容量可配置（默认 100 条目），O(1) 查找/淘汰
- **DiskCache**: `~/Library/Caches/iDocs/` 目录，JSON 编码持久化，带 TTL 过期管理
- TTL 策略参考 apple-docs-mcp 的分级方案：
  - API 搜索结果：30 分钟
  - 框架文档：1 小时
  - 技术目录：2 小时
  - HIG 内容：24 小时（变更频率低）
- 使用 `FileManager` + `NSFileCoordinator` 处理并发文件访问

**Alternatives Considered**:
- SQLite 持久化：引入额外依赖，JSON 文件对本场景已足够
- CloudKit 同步：超出范围，YAGNI 原则

## 5. Apple JSON API 访问策略

**Decision**: UserAgent 随机轮换池 + 403/429 自动重试 + robots.txt 合规。

**Rationale**:
- Apple 的 `developer.apple.com/tutorials/data` 是非公开 API，存在被封风险
- UserAgent 池包含 12+ 常见浏览器 UA（Chrome/Firefox/Safari/Edge），随机选取
- 403/429 响应时：切换 UserAgent 重试，最多 3 次，指数退避
- 参考 sosumi.ai 的合规策略：遵守 robots.txt，添加限速声明

**Alternatives Considered**:
- 单一固定 UserAgent：apple-doc-mcp 的做法，容易被封
- 无限重试：可能导致 IP 被永久封禁，3 次上限更安全

## 6. 优雅关闭 (Graceful Shutdown)

**Decision**: 使用 `swift-service-lifecycle` 的 `ServiceGroup` 管理进程生命周期。

**Rationale**:
- MCP Swift SDK 官方推荐使用 `ServiceGroup` 处理 SIGINT/SIGTERM 信号
- `MCPService` 实现 `Service` 协议，`run()` 启动 Server、`shutdown()` 停止 Server
- 确保缓存写入完成、HTTP 连接断开后再退出进程
- 可配置关闭超时（默认 5 秒）

**Alternatives Considered**:
- Foundation 的 `DispatchSource.makeSignalSource`：更底层，不如 ServiceLifecycle 优雅
- 不处理信号：可能导致缓存数据丢失

## 7. 项目构建工具链

**Decision**: SPM 负责依赖声明 (`Package.swift`)，Tuist 负责 Xcode 工程生成 (`Project.swift`)。

**Rationale**:
- SPM 是 Swift 官方包管理器，所有依赖均支持 SPM
- Tuist 提供 Xcode 工程生成和编译缓存管理，减少 `.xcodeproj` 冲突
- `swift build -c release` 产出静态链接的 Mach-O 二进制

**Alternatives Considered**:
- 纯 SPM（不用 Tuist）：可行，但团队使用 Tuist 已有约定
- CocoaPods/Carthage：已过时，不适合纯 Swift 项目

## 8. 测试策略

**Decision**: Swift Testing 框架，单元测试 + 集成测试分离。

**Rationale**:
- Swift Testing 是 Apple 最新推荐的测试框架，语法更简洁 (`#expect`, `@Test`)
- 单元测试覆盖：DocC 渲染器、缓存层、URL 工具
- 集成测试覆盖：Xcode 本地文档读取、Apple API 请求
- 集成测试可通过 `--filter IntegrationTests` 独立运行
- 开发过程使用 `swift-testing-expert` skill

**Alternatives Considered**:
- XCTest：功能足够但语法较冗长，Swift Testing 是更现代的选择
