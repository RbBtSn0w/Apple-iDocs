# Internal Contracts: Protocols & Dependency Injection

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
    func removeItem(at URL: URL) throws
    func write(_ data: Data, to url: URL) throws
}

extension FileManager: FileSystem {
    public func write(_ data: Data, to url: URL) throws {
        try data.write(to: url)
    }
}
```

## 3. Search Provider Contract (Spotlight)

```swift
public protocol SearchProvider: Sendable {
    func search(query: String) async throws -> [URL]
}
```

## 4. Usage in Data Sources

所有 DataSources 必须提供一个接受上述协议的构造函数：

```swift
public actor AppleJSONAPI {
    public init(session: any NetworkSession = URLSession.shared) { ... }
}
```
