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

// MARK: - DocC Content Nodes

public struct DocCContent: Codable, Sendable {
    public let identifier: String
    public let metadata: DocCMetadata
    public let abstract: [InlineContent]?
    public let primaryContentSections: [ContentSection]?
    public let topicSections: [TopicSection]?
    public let relationshipsSections: [RelationshipSection]?
    public let seeAlsoSections: [SeeAlsoSection]?
    public let references: [String: DocCReference]?
    
    public init(identifier: String, metadata: DocCMetadata, abstract: [InlineContent]? = nil, primaryContentSections: [ContentSection]? = nil, topicSections: [TopicSection]? = nil, relationshipsSections: [RelationshipSection]? = nil, seeAlsoSections: [SeeAlsoSection]? = nil, references: [String: DocCReference]? = nil) {
        self.identifier = identifier
        self.metadata = metadata
        self.abstract = abstract
        self.primaryContentSections = primaryContentSections
        self.topicSections = topicSections
        self.relationshipsSections = relationshipsSections
        self.seeAlsoSections = seeAlsoSections
        self.references = references
    }
}

public enum ContentSection: Codable, Sendable {
    case declarations(DeclarationsSection)
    case parameters(ParametersSection)
    case content(ContentBlockSection)
    case properties(PropertiesSection)
    
    enum CodingKeys: String, CodingKey {
        case kind
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        
        switch kind {
        case "declarations":
            self = .declarations(try DeclarationsSection(from: decoder))
        case "parameters":
            self = .parameters(try ParametersSection(from: decoder))
        case "content":
            self = .content(try ContentBlockSection(from: decoder))
        case "properties":
            self = .properties(try PropertiesSection(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown section kind: \(kind)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        // Implementation for encoding
    }
}

public struct DeclarationsSection: Codable, Sendable {
    public let declarations: [Declaration]
}

public struct Declaration: Codable, Sendable {
    public let tokens: [DeclarationToken]
    public let languages: [String]?
    public let platforms: [String]?
}

public struct DeclarationToken: Codable, Sendable {
    public let kind: String
    public let text: String
    public let identifier: String?
}

public struct ParametersSection: Codable, Sendable {
    public let parameters: [Parameter]
}

public struct Parameter: Codable, Sendable {
    public let name: String
    public let content: [ContentBlock]
}

public struct ContentBlockSection: Codable, Sendable {
    public let content: [ContentBlock]
}

public struct PropertiesSection: Codable, Sendable {
    public let properties: [Property]
}

public struct Property: Codable, Sendable {
    public let name: String
    public let content: [ContentBlock]
}

public enum ContentBlock: Codable, Sendable {
    case paragraph([InlineContent])
    case heading(level: Int, text: String, anchor: String?)
    case codeListing(syntax: String?, code: [String])
    case aside(style: String, content: [ContentBlock])
    case unorderedList([[ContentBlock]])
    case orderedList([[ContentBlock]])
    
    enum CodingKeys: String, CodingKey {
        case type
        case inlineContent
        case level
        case text
        case anchor
        case syntax
        case code
        case style
        case content
        case items
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "paragraph":
            self = .paragraph(try container.decode([InlineContent].self, forKey: .inlineContent))
        case "heading":
            self = .heading(
                level: try container.decode(Int.self, forKey: .level),
                text: try container.decode(String.self, forKey: .text),
                anchor: try container.decodeIfPresent(String.self, forKey: .anchor)
            )
        case "codeListing":
            self = .codeListing(
                syntax: try container.decodeIfPresent(String.self, forKey: .syntax),
                code: try container.decode([String].self, forKey: .code)
            )
        case "aside":
            self = .aside(
                style: try container.decode(String.self, forKey: .style),
                content: try container.decode([ContentBlock].self, forKey: .content)
            )
        case "unorderedList":
            self = .unorderedList(try container.decode([[ContentBlock]].self, forKey: .items))
        case "orderedList":
            self = .orderedList(try container.decode([[ContentBlock]].self, forKey: .items))
        default:
            self = .paragraph([]) // Fallback
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        // Implementation for encoding
    }
}

public enum InlineContent: Codable, Sendable {
    case text(String)
    case codeVoice(String)
    case strong([InlineContent])
    case emphasis([InlineContent])
    case reference(identifier: String, title: String?)
    
    enum CodingKeys: String, CodingKey {
        case type
        case text
        case code
        case inlineContent
        case identifier
        case title
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "codeVoice":
            self = .codeVoice(try container.decode(String.self, forKey: .code))
        case "strong":
            self = .strong(try container.decode([InlineContent].self, forKey: .inlineContent))
        case "emphasis":
            self = .emphasis(try container.decode([InlineContent].self, forKey: .inlineContent))
        case "reference":
            self = .reference(
                identifier: try container.decode(String.self, forKey: .identifier),
                title: try container.decodeIfPresent(String.self, forKey: .title)
            )
        default:
            self = .text("") // Fallback
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        // Implementation for encoding
    }
}

public struct TopicSection: Codable, Sendable {
    public let title: String
    public let identifiers: [String]
}

public struct RelationshipSection: Codable, Sendable {
    public let type: String
    public let title: String
    public let identifiers: [String]
}

public struct SeeAlsoSection: Codable, Sendable {
    public let title: String
    public let identifiers: [String]
}

public struct DocCReference: Codable, Sendable {
    public let title: String
    public let url: String
    public let abstract: [InlineContent]?
}

public struct DocCMetadata: Codable, Sendable {
    public let title: String
    public let role: String?
    public let platforms: [PlatformAvailability]?
}
