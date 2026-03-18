import Foundation

public enum RetrievalSource: String, Sendable, Equatable {
    case cache
    case local
    case apple
    case sosumi
}

public struct DocumentationContent: Sendable, Equatable {
    public let title: String
    public let body: String
    public let metadata: [String: String]
    public let url: URL

    public init(title: String, body: String, metadata: [String: String] = [:], url: URL) {
        self.title = title
        self.body = body
        self.metadata = metadata
        self.url = url
    }
}

public struct SearchResult: Sendable, Equatable {
    public let id: String
    public let title: String
    public let snippet: String?
    public let technology: String
    public let source: RetrievalSource?

    public init(id: String, title: String, snippet: String?, technology: String, source: RetrievalSource? = nil) {
        self.id = id
        self.title = title
        self.snippet = snippet
        self.technology = technology
        self.source = source
    }
}

public struct Technology: Sendable, Equatable {
    public let name: String
    public let id: String
    public let category: String?

    public init(name: String, id: String, category: String?) {
        self.name = name
        self.id = id
        self.category = category
    }
}
