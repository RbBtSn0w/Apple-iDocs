# MCP Tool Contracts: iDocs

**Branch**: `001-swift-apple-docs-mcp` | **Date**: 2026-03-13

本文档定义了 iDocs MCP Server 暴露的 7 个工具的接口契约。

---

## 1. `search_docs` — 搜索 Apple 文档

**Description**: 搜索 Apple 开发者文档。优先查询本地 Xcode 索引，若无结果则回落到在线 API。

**Input Schema**:
```json
{
  "type": "object",
  "properties": {
    "query": {
      "type": "string",
      "description": "搜索关键词，支持通配符 (* 和 ?)"
    },
    "framework": {
      "type": "string",
      "description": "可选，限定搜索范围到特定框架 (如 'swiftui', 'uikit')"
    },
    "language": {
      "type": "string",
      "enum": ["swift", "objectivec"],
      "description": "可选，筛选编程语言，默认 'swift'"
    },
    "limit": {
      "type": "integer",
      "description": "可选，返回结果数量上限，默认 10",
      "default": 10
    }
  },
  "required": ["query"]
}
```

**Output**: Markdown 格式的搜索结果列表，每条包含标题、摘要、路径和来源。

---

## 2. `fetch_doc` — 获取文档完整内容

**Description**: 获取指定路径的 Apple 文档完整内容，返回高质量 Markdown 格式。

**Input Schema**:
```json
{
  "type": "object",
  "properties": {
    "path": {
      "type": "string",
      "description": "文档路径 (如 '/documentation/swiftui/view')"
    }
  },
  "required": ["path"]
}
```

**Output**: 完整的 Markdown 格式文档，包含声明、参数、说明、代码示例、注意事项等。

---

## 3. `fetch_hig` — 获取 HIG 人机界面指南

**Description**: 获取 Apple Human Interface Guidelines 指定主题的内容。

**Input Schema**:
```json
{
  "type": "object",
  "properties": {
    "topic": {
      "type": "string",
      "description": "HIG 主题标识 (如 'navigation', 'buttons', 'color')"
    }
  },
  "required": ["topic"]
}
```

**Output**: 指定 HIG 主题的完整 Markdown 内容。

---

## 4. `browse_technologies` — 浏览技术目录

**Description**: 浏览 Apple 技术框架分类目录。

**Input Schema**:
```json
{
  "type": "object",
  "properties": {
    "category": {
      "type": "string",
      "description": "可选，按分类筛选 (如 'app-frameworks', 'graphics-and-games')"
    }
  },
  "required": []
}
```

**Output**: 技术框架分类列表，包含框架名称、描述和文档入口路径。

---

## 5. `fetch_external_doc` — 获取第三方 DocC 文档

**Description**: 获取第三方 Swift 包的 DocC 格式文档。

**Input Schema**:
```json
{
  "type": "object",
  "properties": {
    "url": {
      "type": "string",
      "description": "第三方 DocC 文档的完整 URL"
    }
  },
  "required": ["url"]
}
```

**Output**: 指定第三方文档的 Markdown 内容。

---

## 6. `fetch_video_transcript` — 获取 WWDC 视频转录

**Description**: 获取 Apple WWDC 视频的文字转录内容。

**Input Schema**:
```json
{
  "type": "object",
  "properties": {
    "videoID": {
      "type": "string",
      "description": "WWDC 视频标识 (如 'wwdc2024-10001' 或完整 URL)"
    }
  },
  "required": ["videoID"]
}
```

**Output**: 视频标题和完整的文字转录内容。

---

## 7. `xcode_docs` — 查询 Xcode 本地文档 ⭐

**Description**: 查询用户 Xcode 本地已下载的文档。这是 iDocs 独有的核心功能。

**Input Schema**:
```json
{
  "type": "object",
  "properties": {
    "action": {
      "type": "string",
      "enum": ["search", "list"],
      "description": "'search' 搜索符号，'list' 列出已下载的文档集"
    },
    "symbol": {
      "type": "string",
      "description": "要查询的符号名称 (如 'Array.append', 'UIView')。action=search 时必填，action=list 时忽略"
    }
  },
  "required": ["action"],
  "if": { "properties": { "action": { "const": "search" } } },
  "then": { "required": ["action", "symbol"] },
  "else": { "properties": { "symbol": false }, "errorMessage": "action 为 list 时必须省略 symbol 参数" }
}
```

**Conditional Constraints**:
- `action=search` → `symbol` **required**
- `action=list` → `symbol` **forbidden** (传入也会被忽略)

**Output**:
- `search` 模式：匹配符号的本地文档内容
- `list` 模式：已下载的 SDK 文档集列表及版本信息

---

## Error Contract

所有工具的错误响应格式统一：

```json
{
  "content": [{"type": "text", "text": "错误描述信息"}],
  "isError": true
}
```

错误信息要求：
- 使用自然语言描述，AI 助手可理解
- 包含错误原因和建议的后续操作
- 示例：`"在本地 Xcode 文档中未找到 'XXX'。建议：1) 检查 Xcode 是否已下载文档；2) 使用 search_docs 工具进行在线搜索。"`
