import Foundation

// MARK: - Network

public protocol NetworkSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: @unchecked Sendable, NetworkSession {}

// MARK: - File System

public protocol FileSystem: Sendable {
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions) throws -> [URL]
    func fileExists(atPath path: String) -> Bool
    func removeItem(at url: URL) throws
    func write(_ data: Data, to url: URL) throws
    func read(from url: URL) throws -> Data
}

extension FileManager: @unchecked Sendable, FileSystem {
    public func write(_ data: Data, to url: URL) throws {
        try data.write(to: url)
    }
    
    public func read(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }
}

// MARK: - Search Provider

public protocol SearchProvider: Sendable {
    func search(query: String) async throws -> [URL]
}

// MARK: - Mock Errors

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
