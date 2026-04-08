import Foundation
@testable import iDocsKit

public final class MockFileSystem: FileSystem, @unchecked Sendable {
    public var virtualFiles: [String: Data] = [:]
    public var stubbedError: Error?
    
    public init(virtualFiles: [String: Data] = [:], stubbedError: Error? = nil) {
        self.virtualFiles = Dictionary(
            uniqueKeysWithValues: virtualFiles.map { (Self.canonicalPath($0.key), $0.value) }
        )
        self.stubbedError = stubbedError
    }
    
    public func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        if let error = stubbedError { throw error }
        
        let path = Self.canonicalPath(url.path)
        let filtered = virtualFiles.keys.filter {
            let candidate = Self.canonicalPath($0)
            guard candidate.hasPrefix(path), candidate != path else { return false }
            let relative = candidate.dropFirst(path.count).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return !relative.isEmpty && !relative.contains("/")
        }
        return filtered.map { item in
            if item.hasSuffix("/") {
                return URL(fileURLWithPath: item, isDirectory: true)
            }
            return URL(fileURLWithPath: item)
        }
    }
    
    public func fileExists(atPath path: String) -> Bool {
        let canonical = Self.canonicalPath(path)
        return virtualFiles.keys.contains { Self.canonicalPath($0) == canonical }
    }
    
    public func removeItem(at url: URL) throws {
        if let error = stubbedError { throw error }
        let canonical = Self.canonicalPath(url.path)
        if let key = virtualFiles.keys.first(where: { Self.canonicalPath($0) == canonical }) {
            virtualFiles.removeValue(forKey: key)
        }
    }
    
    public func write(_ data: Data, to url: URL) throws {
        if let error = stubbedError { throw error }
        virtualFiles[Self.canonicalPath(url.path)] = data
    }
    
    public func read(from url: URL) throws -> Data {
        if let error = stubbedError { throw error }
        let canonical = Self.canonicalPath(url.path)
        guard let key = virtualFiles.keys.first(where: { Self.canonicalPath($0) == canonical }),
              let data = virtualFiles[key] else {
            throw MockError.fileNotFound
        }
        return data
    }
    
    public func reset() {
        virtualFiles.removeAll()
        stubbedError = nil
    }

    private static func canonicalPath(_ path: String) -> String {
        var result = path
        while result.contains("//") {
            result = result.replacingOccurrences(of: "//", with: "/")
        }
        while result.count > 1 && result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }
}
