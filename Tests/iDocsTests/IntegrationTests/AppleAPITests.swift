import Testing
import Foundation
@testable import iDocsKit

@Suite("Apple JSON API Tests")
struct AppleAPITests {
    
    @Test("Search URL construction")
    func searchURL() {
        let query = "SwiftUI"
        let url = URLHelpers.searchURL(query: query)
        #expect(url?.absoluteString == "https://developer.apple.com/tutorials/data/documentation.json?q=SwiftUI")
    }

    @Test("Technologies URL construction")
    func technologiesURL() {
        let url = URLHelpers.technologiesURL()
        #expect(url?.absoluteString == "https://developer.apple.com/tutorials/data/documentation/technologies.json")
    }
    
    @Test("Parse Search Result JSON")
    func parseSearch() throws {
        let json = """
        {
            "references": {
                "doc://com.apple.documentation/documentation/SwiftUI/View": {
                    "title": "View",
                    "kind": "protocol",
                    "url": "/documentation/swiftui/view",
                    "abstract": [
                        {
                            "type": "text",
                            "text": "A type that represents part of your user interface."
                        }
                    ]
                }
            }
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(AppleSearchResponse.self, from: json)
        
        #expect(response.references.count == 1)
        let first = response.references.values.first
        #expect(first?.title == "View")
        #expect(first?.kind == .protocol)
    }
}

// MARK: - Mock Types for Testing

struct AppleSearchResponse: Codable {
    let references: [String: AppleSearchResult]
}

struct AppleSearchResult: Codable {
    let title: String
    let type: String?
    let kindValue: String?
    let url: String
    let abstract: [InlineText]?

    enum CodingKeys: String, CodingKey {
        case title
        case type
        case kindValue = "kind"
        case url
        case abstract
    }
    
    var kind: DocumentKind {
        return DocumentKind(rawValue: kindValue ?? type ?? "") ?? .overview
    }
}

struct InlineText: Codable {
    let type: String?
    let text: String?
}
