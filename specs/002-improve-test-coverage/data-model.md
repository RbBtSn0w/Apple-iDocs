# Data Model: 提高项目可测试性与单元测试覆盖率

## 核心抽象协议 (Core Protocols)

### NetworkSession
用于抽象网络请求，使 `AppleJSONAPI` 等组件可测试。

| 方法 | 返回值 | 说明 |
|------|--------|------|
| `data(for: URLRequest)` | `(Data, URLResponse)` | 异步获取数据，支持抛出 `MockError` |

### FileSystem
用于抽象本地磁盘 IO，使 `DiskCache` 和 `XcodeLocalDocs` 可测试。

| 方法 | 说明 |
|------|------|
| `contentsOfDirectory(at:...)` | 遍历目录 |
| `fileExists(atPath:)` | 检查路径是否存在 |
| `removeItem(at:)` | 删除文件/目录 |
| `write(_:to:)` | 写入数据 |

### SearchProvider
用于抽象 Spotlight (`NSMetadataQuery`) 本地搜索逻辑。

| 方法 | 说明 |
|------|------|
| `search(query: String)` | 执行模糊匹配，返回匹配的文档路径列表 |

## 测试实体 (Test Entities)

### Mock 状态管理
所有 Mock 实体必须包含以下共性行为：
- `reset()`: 重置所有记录的调用次数和 Stub 返回值。
- `stubbedError`: 可选的 `MockError` 成员，用于触发异常路径。

### Mock 对象定义
- **MockNetworkSession**: 支持 Stubbing `Data` 和 `URLResponse`。
- **MockFileSystem**: 在内存中维护一个虚拟文件字典，模拟真实读写。
- **MockSearchProvider**: 支持预设一组路径作为搜索结果。

## 实体关系图 (Entity Relationships)

```text
AppleJSONAPI ----> [NetworkSession]
DiskCache --------> [FileSystem]
XcodeLocalDocs ---> [FileSystem] + [SearchProvider]
SearchDocsTool ---> [AppleJSONAPI] + [XcodeLocalDocs] + [MemoryCache]
```
