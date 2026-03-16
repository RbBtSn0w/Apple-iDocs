import Testing
import Foundation
@testable import iDocsKit

@Suite("Cache Tests")
struct CacheTests {
    
    // MARK: - MemoryCache Tests
    
    @Test("MemoryCache basic set and get")
    func memoryCacheBasic() async throws {
        let cache = MemoryCache<String, String>(capacity: 2)
        await cache.set("key1", value: "value1")
        let value = await cache.get("key1")
        #expect(value == "value1")
    }
    
    @Test("MemoryCache LRU eviction")
    func memoryCacheLRU() async throws {
        let cache = MemoryCache<String, String>(capacity: 2)
        await cache.set("key1", value: "value1")
        await cache.set("key2", value: "value2")
        await cache.set("key3", value: "value3") // Should evict key1
        
        let val1 = await cache.get("key1")
        let val2 = await cache.get("key2")
        let val3 = await cache.get("key3")
        
        #expect(val1 == nil)
        #expect(val2 == "value2")
        #expect(val3 == "value3")
    }
    
    @Test("MemoryCache access updates LRU order")
    func memoryCacheLRUOrder() async throws {
        let cache = MemoryCache<String, String>(capacity: 2)
        await cache.set("key1", value: "value1")
        await cache.set("key2", value: "value2")
        
        _ = await cache.get("key1") // Access key1 to make it most recent
        await cache.set("key3", value: "value3") // Should evict key2
        
        let val1 = await cache.get("key1")
        let val2 = await cache.get("key2")
        let val3 = await cache.get("key3")
        
        #expect(val1 == "value1")
        #expect(val2 == nil)
        #expect(val3 == "value3")
    }
    
    @Test("MemoryCache high concurrency stability")
    func memoryCacheConcurrency() async throws {
        let cache = MemoryCache<Int, Int>(capacity: 100)
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<1000 {
                group.addTask {
                    await cache.set(i % 50, value: i)
                }
            }
        }
        
        // Should not crash and have 50 items
        // We can't easily check internal count as it's private, 
        // but getting items should work.
        for i in 0..<50 {
            let val = await cache.get(i)
            #expect(val != nil)
        }
    }
    
    @Test("MemoryCache reset and clear")
    func memoryCacheClear() async throws {
        let cache = MemoryCache<String, String>(capacity: 10)
        await cache.set("k", value: "v")
        await cache.clear()
        let val = await cache.get("k")
        #expect(val == nil)
    }
    
    // MARK: - DiskCache Tests
    
    @Test("DiskCache basic write and read")
    func diskCacheBasic() async throws {
        let cache = DiskCache(name: "test_cache")
        let data = "test_data".data(using: .utf8)!
        
        try await cache.set("key1", value: data, ttl: 60)
        let retrieved = try await cache.get("key1")
        
        #expect(retrieved == data)
        
        // Cleanup
        try await cache.clear()
    }
    
    @Test("DiskCache TTL expiration")
    func diskCacheExpiration() async throws {
        let cache = DiskCache(name: "test_expiration")
        let data = "expired".data(using: .utf8)!
        
        // Set with 0 TTL (or very short)
        try await cache.set("key1", value: data, ttl: -1)
        
        let retrieved = try await cache.get("key1")
        #expect(retrieved == nil)
        
        // Cleanup
        try await cache.clear()
    }
}
