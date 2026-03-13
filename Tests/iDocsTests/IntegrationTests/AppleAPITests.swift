import Testing
import Foundation
@testable import iDocs

@Suite("Apple JSON API Tests")
struct AppleAPITests {
    
    @Test("Search URL construction")
    func searchURL() {
        let query = "SwiftUI"
        let url = URLHelpers.dataURL(for: "search?q=\(query)")
        #expect(url?.absoluteString == "https://developer.apple.com/tutorials/data/search?q=SwiftUI.json")
    }
    
    @Test("Parse Search Result JSON")
    func parseSearch() throws {
        let json = """
        {
            "results": [
                {
                    "title": "View",
                    "type": "protocol",
                    "url": "/documentation/swiftui/view",
                    "abstract": "A type that represents part of your user interface."
                }
            ]
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(AppleSearchResponse.self, from: json)
        
        #expect(response.results.count == 1)
        #expect(response.results[0].title == "View")
        #expect(response.results[0].kind == .protocol)
    }
}

// MARK: - Mock Types for Testing

struct AppleSearchResponse: Codable {
    let results: [AppleSearchResult]
}

struct AppleSearchResult: Codable {
    let title: String
    let type: String
    let url: String
    let abstract: String?
    
    var kind: DocumentKind {
        return DocumentKind(rawValue: type) ?? .overview
    }
}
