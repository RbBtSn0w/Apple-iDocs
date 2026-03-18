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

    private func makeMockSosumiAPI(queries: [String]) -> SosumiAPI {
        let session = MockNetworkSession()
        for query in queries {
            if let url = URLHelpers.sosumiSearchURL(query: query) {
                let response = MockPayloads.httpResponse(url: url)
                session.setResponse(for: url, data: MockPayloads.sosumiSearchJSON, response: response)
            }
        }
        return SosumiAPI(session: session)
    }
    
    @Test("SearchDocsTool handles basic query")
    func searchToolBasic() async throws {
        let api = makeMockAPI(queries: ["View"])
        let sosumi = makeMockSosumiAPI(queries: ["View"])
        let tool = SearchDocsTool(api: api, sosumiAPI: sosumi, memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5))
        let result = try await tool.run(query: "View")
        
        #expect(!result.isEmpty)
        #expect(result.first?.title == "View")
    }
    
    @Test("SearchDocsTool handles wildcards")
    func searchToolWildcard() async throws {
        let api = makeMockAPI(queries: ["NS*Controller"])
        let sosumi = makeMockSosumiAPI(queries: ["NS*Controller"])
        let tool = SearchDocsTool(api: api, sosumiAPI: sosumi, memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5))
        let result = try await tool.run(query: "NS*Controller")
        
        #expect(!result.isEmpty)
        #expect(result.first?.source == .sosumi || result.first?.source == .apple)
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

    @Test("AppleJSONAPI parses modern technologies payload")
    func parseModernTechnologiesPayload() async throws {
        let session = MockNetworkSession()
        if let techURL = URLHelpers.technologiesURL() {
            session.setResponse(
                for: techURL,
                data: MockPayloads.technologiesModernJSON,
                response: MockPayloads.httpResponse(url: techURL)
            )
        }

        let api = AppleJSONAPI(session: session)
        let techs = try await api.fetchTechnologies()
        #expect(techs.count == 1)
        #expect(techs.first?.name == "SwiftUI")
        #expect(techs.first?.url == "/documentation/swiftui")
    }

    @Test("SearchDocsTool falls back to sosumi when apple remote misses")
    func searchToolFallsBackToSosumi() async throws {
        let api = makeMockAPI(queries: ["NoLocalHit"])
        let sosumi = makeMockSosumiAPI(queries: ["NoLocalHit"])
        let tool = SearchDocsTool(api: api, sosumiAPI: sosumi, memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5))

        let result = try await tool.run(query: "NoLocalHit")
        #expect(!result.isEmpty)
        #expect(result.first?.source == .sosumi)
    }

    @Test("SearchDocsTool prefers local results over remote")
    func searchToolPrefersLocal() async throws {
        let apiSession = MockNetworkSession(stubbedError: MockError.networkTimeout)
        let apple = AppleJSONAPI(session: apiSession)
        let sosumiSession = MockNetworkSession(stubbedError: MockError.networkTimeout)
        let sosumi = SosumiAPI(session: sosumiSession)

        let mockFS = MockFileSystem()
        let mockSearch = MockSearchProvider(
            mockResults: [URL(fileURLWithPath: "/tmp/DocumentationCache/documentation/swiftui/view.json")]
        )
        let xcodeDocs = XcodeLocalDocs(fileManager: mockFS, searchProvider: mockSearch)

        let tool = SearchDocsTool(
            api: apple,
            sosumiAPI: sosumi,
            xcodeDocs: xcodeDocs,
            memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5)
        )

        let result = try await tool.run(query: "View")
        #expect(!result.isEmpty)
        #expect(result.first?.source == .local)
        #expect(apiSession.requestCount == 0)
        #expect(sosumiSession.requestCount == 0)
    }
}
