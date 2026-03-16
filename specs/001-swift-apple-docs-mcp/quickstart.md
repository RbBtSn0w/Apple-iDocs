# Quickstart: iDocs MCP Server

**Branch**: `001-swift-apple-docs-mcp` | **Date**: 2026-03-13

## 前置条件

- macOS 13.0+
- Swift 6.2+ (Xcode 16+)
- Tuist (可选，用于 Xcode 工程管理)

## 构建

```bash
# 克隆项目
git clone https://github.com/<org>/awesome-iDocs-mcp.git
cd awesome-iDocs-mcp

# 使用 SPM 构建
swift build

# 构建 Release 版本（静态链接，单二进制）
swift build -c release
```

## 运行

### Stdio 模式（本地 IDE）

```bash
# 直接运行
.build/release/iDocs

# 或通过 swift run
swift run iDocs
```

### HTTP 模式（远程 Agent）

```bash
swift run iDocs --transport http --port 8080
```

## 配置 AI 客户端

### Claude Desktop

在 `~/Library/Application Support/Claude/claude_desktop_config.json` 中添加：

```json
{
  "mcpServers": {
    "idocs": {
      "command": "/path/to/iDocs"
    }
  }
}
```

### Cursor

在 `.cursor/mcp.json` 中添加：

```json
{
  "mcpServers": {
    "idocs": {
      "command": "/path/to/iDocs"
    }
  }
}
```

## 验证

### MCP Inspector

```bash
npx @modelcontextprotocol/inspector /path/to/iDocs
```

在 Inspector UI 中：
1. 确认连接成功
2. 查看 7 个工具列表
3. 调用 `search_docs` 工具测试搜索功能
4. 调用 `xcode_docs` 工具测试本地文档访问

### 运行测试

```bash
# 全量测试
swift test

# 启用集成测试（环境变量方式）
IDOCS_INTEGRATION_TESTS=1 swift test

# 仅集成测试（过滤器方式）
swift test --filter IntegrationTests
```

说明：
- 默认测试不访问外部网络
- 使用 `swift test --filter IntegrationTests` 时视为集成模式

## 常见问题

**Q: 为什么 `xcode_docs` 工具返回"本地文档不可用"？**
A: 需要通过 Xcode → Settings → Components 下载对应平台的文档。

**Q: 搜索返回 403 错误怎么办？**
A: 系统会自动切换 UserAgent 重试。如果持续失败，可能是 IP 被 Apple 暂时限制，等待几分钟后重试。
