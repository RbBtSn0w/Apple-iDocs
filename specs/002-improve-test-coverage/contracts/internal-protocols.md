# Internal Contracts: Protocols & Mocking

## 1. Network Contract

```swift
public protocol NetworkSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkSession {}
```

## 2. File System Contract

```swift
public protocol FileSystem: Sendable {
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions) throws -> [URL]
    func fileExists(atPath path: String) -> Bool
    func removeItem(at url: URL) throws
    func write(_ data: Data, to url: URL) throws
}

extension FileManager: FileSystem {
    public func write(_ data: Data, to url: URL) throws {
        try data.write(to: url)
    }
}
```

## 3. Search Provider Contract

```swift
public protocol SearchProvider: Sendable {
    func search(query: String) async throws -> [URL]
}
```

## 4. Mock Error Definitions

为了确保测试环境中能完整覆盖各种异常路径，定义统一的 `MockError` 枚举以供 Mock 实体抛出：

```swift
public enum MockError: Error, Equatable, Sendable {
    /// 模拟权限不足 (如文件读写权限被拒)
    case noPermission
    
    /// 模拟磁盘空间不足
    case diskFull
    
    /// 模拟网络请求超时
    case networkTimeout
    
    /// 模拟无效或解析失败的网络响应
    case invalidResponse
    
    /// 模拟文件或目录未找到
    case fileNotFound
}
```

## 5. Implementation Requirements

所有重构后的组件 **必须** 满足以下依赖注入契约：

```swift
public actor AppleJSONAPI {
    // 默认值保证生产环境兼容性，显式注入保证测试可控制
    public init(session: any NetworkSession = URLSession.shared) { ... }
}
```
