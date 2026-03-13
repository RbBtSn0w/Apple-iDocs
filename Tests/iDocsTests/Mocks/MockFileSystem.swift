import Foundation
@testable import iDocs

public final class MockFileSystem: FileSystem, @unchecked Sendable {
    public var virtualFiles: [String: Data] = [:]
    public var stubbedError: Error?
    
    public init(virtualFiles: [String: Data] = [:], stubbedError: Error? = nil) {
        self.virtualFiles = virtualFiles
        self.stubbedError = stubbedError
    }
    
    public func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        if let error = stubbedError { throw error }
        
        let path = url.path
        let filtered = virtualFiles.keys.filter { $0.hasPrefix(path) && $0 != path }
        return filtered.map { URL(fileURLWithPath: $0) }
    }
    
    public func fileExists(atPath path: String) -> Bool {
        return virtualFiles[path] != nil
    }
    
    public func removeItem(at url: URL) throws {
        if let error = stubbedError { throw error }
        virtualFiles.removeValue(forKey: url.path)
    }
    
    public func write(_ data: Data, to url: URL) throws {
        if let error = stubbedError { throw error }
        virtualFiles[url.path] = data
    }
    
    public func read(from url: URL) throws -> Data {
        if let error = stubbedError { throw error }
        guard let data = virtualFiles[url.path] else {
            throw MockError.fileNotFound
        }
        return data
    }
    
    public func reset() {
        virtualFiles.removeAll()
        stubbedError = nil
    }
}
