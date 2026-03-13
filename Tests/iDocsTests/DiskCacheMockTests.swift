import Testing
import Foundation
@testable import iDocs

@Suite("DiskCache Mock Tests")
struct DiskCacheMockTests {
    
    @Test("DiskCache handles write error (no permission)")
    func testWriteError() async throws {
        let mockFS = MockFileSystem()
        let cache = DiskCache(name: "test", fileManager: mockFS)
        let data = "data".data(using: .utf8)!
        
        mockFS.stubbedError = MockError.noPermission
        
        await #expect(throws: Error.self) {
            try await cache.set("key", value: data, ttl: 60)
        }
    }
    
    @Test("DiskCache handles disk full")
    func testDiskFull() async throws {
        let mockFS = MockFileSystem()
        let cache = DiskCache(name: "test", fileManager: mockFS)
        let data = "data".data(using: .utf8)!
        
        mockFS.stubbedError = MockError.diskFull
        
        await #expect(throws: Error.self) {
            try await cache.set("key", value: data, ttl: 60)
        }
    }
}
