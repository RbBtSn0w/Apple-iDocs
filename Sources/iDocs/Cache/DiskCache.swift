import Foundation

public struct DiskCache {
    private let cacheDirectory: URL
    private let fileManager: any FileSystem
    
    public init(name: String, fileManager: any FileSystem = FileManager.default) {
        self.fileManager = fileManager
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cachesURL.appendingPathComponent("iDocs").appendingPathComponent(name)
        
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    public func get(_ key: String) async throws -> Data? {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try fileManager.read(from: fileURL)
        let wrapper = try JSONDecoder().decode(DiskCacheWrapper.self, from: data)
        
        if Date() > wrapper.expiresAt {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        
        return wrapper.data
    }
    
    public func set(_ key: String, value: Data, ttl: TimeInterval) async throws {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256)
        let expiresAt = Date().addingTimeInterval(ttl)
        let wrapper = DiskCacheWrapper(data: value, expiresAt: expiresAt)
        
        let data = try JSONEncoder().encode(wrapper)
        try fileManager.write(data, to: fileURL)
    }
    
    public func remove(_ key: String) async throws {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    public func clear() async throws {
        let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil, options: [])
        for url in contents {
            try fileManager.removeItem(at: url)
        }
    }
}

// MARK: - Private Wrapper

private struct DiskCacheWrapper: Codable {
    let data: Data
    let expiresAt: Date
}

// MARK: - String Extension for Hashing

import CryptoKit

private extension String {
    var sha256: String {
        let inputData = Data(self.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
