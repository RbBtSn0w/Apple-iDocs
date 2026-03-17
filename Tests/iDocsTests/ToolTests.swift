import Testing
import Foundation
@testable import iDocsKit

@Suite("SearchDocsTool Integration Tests")
struct ToolTests {

    private func makeMockAPI(queries: [String]) -> AppleJSONAPI {
        let session = MockNetworkSession()
        for query in queries {
            if let url = URLHelpers.searchURL(query: query) {
                let response = MockPayloads.httpResponse(url: url)
                session.setResponse(for: url, data: MockPayloads.searchJSON, response: response)
            }
        }
        if let techUrl = URLHelpers.technologiesURL() {
            let response = MockPayloads.httpResponse(url: techUrl)
            session.setResponse(for: techUrl, data: MockPayloads.technologiesJSON, response: response)
        }
        return AppleJSONAPI(session: session)
    }
    
    @Test("SearchDocsTool handles basic query")
    func searchToolBasic() async throws {
        let api = makeMockAPI(queries: ["View"])
        let tool = SearchDocsTool(api: api, memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5))
        let result = try await tool.run(query: "View")
        
        #expect(!result.isEmpty)
        #expect(result.first?.title == "View")
    }
    
    @Test("SearchDocsTool handles wildcards")
    func searchToolWildcard() async throws {
        let api = makeMockAPI(queries: ["NS*Controller"])
        let tool = SearchDocsTool(api: api, memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5))
        let result = try await tool.run(query: "NS*Controller")
        
        #expect(!result.isEmpty)
    }
    
    @Test("BrowseTechnologiesTool lists technologies")
    func browseTechs() async throws {
        let api = makeMockAPI(queries: [])
        let tool = BrowseTechnologiesTool(api: api)
        let result = try await tool.run()
        #expect(!result.isEmpty)
        #expect(result.contains("SwiftUI"))
    }

    @Test("AppleJSONAPI parses search payload")
    func parseSearchPayload() async throws {
        let api = makeMockAPI(queries: ["View"])
        let results = try await api.search(query: "View")
        #expect(results.count == 1)
        #expect(results.first?.path == "/documentation/swiftui/view")
    }

    @Test("AppleJSONAPI parses technologies payload")
    func parseTechnologiesPayload() async throws {
        let api = makeMockAPI(queries: [])
        let techs = try await api.fetchTechnologies()
        #expect(techs.count == 1)
        #expect(techs.first?.name == "SwiftUI")
    }
}
