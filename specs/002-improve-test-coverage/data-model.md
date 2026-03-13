# Data Model: 提高项目可测试性与单元测试覆盖率

## 核心抽象协议 (Core Protocols)

### NetworkSession
用于抽象网络 IO，解耦 `URLSession`。

| 方法 | 说明 |
|------|------|
| `data(for: URLRequest)` | 异步获取数据与响应，支持抛出网络错误。 |

### FileSystem
用于抽象磁盘 IO，解耦 `FileManager`。

| 方法 | 说明 |
|------|------|
| `contentsOfDirectory(at:includingPropertiesForKeys:options:)` | 枚举目录。 |
| `fileExists(atPath:)` | 检查路径。 |
| `removeItem(at:)` | 删除文件。 |
| `write(_:to:)` | 写入数据。 |

### SearchProvider (Spotlight)
用于抽象本地元数据查询。

| 方法 | 说明 |
|------|------|
| `execute(query: String)` | 执行搜索并返回路径列表。 |

## 测试实体 (Test Entities)

### MockNetworkSession
实现 `NetworkSession` 协议。
- **属性**: `stubbedData`, `stubbedResponse`, `stubbedError`。
- **行为**: 根据预设值返回数据或抛出错误。

### MockFileSystem
实现 `FileSystem` 协议。
- **属性**: `virtualFiles: [String: Data]` (内存中的虚拟文件系统)。
- **行为**: 模拟文件读写、权限错误、磁盘空间满等场景。

### MockSearchProvider
实现 `SearchProvider` 协议。
- **属性**: `mockResults: [String]`。
- **行为**: 模拟 Spotlight 搜索结果。

## 关联关系

- `AppleJSONAPI` -> 依赖 `NetworkSession`
- `XcodeLocalDocs` -> 依赖 `FileSystem` + `SearchProvider`
- `DiskCache` -> 依赖 `FileSystem`
- `FetchDocTool` -> 依赖 `AppleJSONAPI` + `XcodeLocalDocs`
