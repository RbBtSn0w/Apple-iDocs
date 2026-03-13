import Foundation

// MARK: - Core Enums

public enum DocumentKind: String, Codable, Sendable {
    case framework, `class`, structure, `protocol`, enumeration
    case function, property, `typealias`, `associatedtype`
    case `operator`, macro, variable, initializer
    case instanceMethod, typeMethod, instanceProperty, typeProperty
    case article, sampleCode, overview
}

public enum SourceLanguage: String, Codable, Sendable {
    case swift, objectivec
}

public enum DataSource: String, Codable, Sendable {
    case xcode       // Xcode 本地文档
    case diskCache   // 磁盘缓存
    case remote      // 远程 API
}

// MARK: - Core Entities

public struct DocumentationEntry: Codable, Sendable {
    public let identifier: String
    public let title: String
    public let abstract: String?
    public let kind: DocumentKind
    public let language: SourceLanguage
    public let platforms: [PlatformAvailability]?
    public let url: URL
    // content will be added later or as a separate type to avoid bloating search results
}

public struct PlatformAvailability: Codable, Sendable {
    public let name: String
    public let introducedAt: String?
    public let deprecatedAt: String?
    public let beta: Bool?
}

public struct SearchResult: Codable, Sendable {
    public let title: String
    public let abstract: String?
    public let path: String
    public let kind: DocumentKind
    public let source: DataSource
    public let relevance: Double?
    
    public init(title: String, abstract: String?, path: String, kind: DocumentKind, source: DataSource, relevance: Double? = nil) {
        self.title = title
        self.abstract = abstract
        self.path = path
        self.kind = kind
        self.source = source
        self.relevance = relevance
    }
}

// MARK: - Cache Entities

public struct CacheEntry<T: Codable & Sendable>: Codable, Sendable {
    public let key: String
    public let value: T
    public let createdAt: Date
    public let expiresAt: Date
    public let source: DataSource
    public var lastAccessedAt: Date
    
    public var isExpired: Bool {
        return Date() > expiresAt
    }
    
    public init(key: String, value: T, ttl: TimeInterval, source: DataSource) {
        let now = Date()
        self.key = key
        self.value = value
        self.createdAt = now
        self.expiresAt = now.addingTimeInterval(ttl)
        self.source = source
        self.lastAccessedAt = now
    }
}

// MARK: - DocC Content Nodes (Simplified for now)

public struct DocCContent: Codable, Sendable {
    // This will be expanded in US2 implementation
    public let identifier: String
    public let metadata: DocCMetadata
    // Other fields as defined in data-model.md
}

public struct DocCMetadata: Codable, Sendable {
    public let title: String
    public let role: String?
    public let platforms: [PlatformAvailability]?
}
