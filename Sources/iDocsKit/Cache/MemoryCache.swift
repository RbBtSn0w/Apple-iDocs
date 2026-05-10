import Foundation

public actor MemoryCache<Key: Hashable & Sendable, Value: Sendable> {
    private let capacity: Int
    private var cache: [Key: CacheNode] = [:]
    private var head: CacheNode?
    private var tail: CacheNode?
    
    private class CacheNode {
        let key: Key
        var value: Value
        var prev: CacheNode?
        var next: CacheNode?
        
        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }
    
    public init(capacity: Int = 100) {
        self.capacity = capacity
    }
    
    public func get(_ key: Key) -> Value? {
        guard let node = cache[key] else { return nil }
        moveToHead(node)
        return node.value
    }
    
    public func set(_ key: Key, value: Value) {
        if let node = cache[key] {
            node.value = value
            moveToHead(node)
        } else {
            let newNode = CacheNode(key: key, value: value)
            cache[key] = newNode
            addNode(newNode)
            
            if cache.count > capacity {
                if let lruNode = popTail() {
                    cache.removeValue(forKey: lruNode.key)
                }
            }
        }
    }
    
    public func remove(_ key: Key) {
        if let node = cache.removeValue(forKey: key) {
            removeNode(node)
        }
    }
    
    public func clear() {
        cache.removeAll()
        head = nil
        tail = nil
    }
    
    // MARK: - Private Doubly Linked List Operations
    
    private func addNode(_ node: CacheNode) {
        node.prev = nil
        node.next = head
        
        if let head = head {
            head.prev = node
        }
        head = node
        
        if tail == nil {
            tail = node
        }
    }
    
    private func removeNode(_ node: CacheNode) {
        let prev = node.prev
        let next = node.next
        
        if let prev = prev {
            prev.next = next
        } else {
            head = next
        }
        
        if let next = next {
            next.prev = prev
        } else {
            tail = prev
        }
    }
    
    private func moveToHead(_ node: CacheNode) {
        removeNode(node)
        addNode(node)
    }
    
    private func popTail() -> CacheNode? {
        guard let res = tail else { return nil }
        removeNode(res)
        return res
    }
}
