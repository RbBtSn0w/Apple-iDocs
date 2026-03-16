import Testing
import Foundation
@testable import iDocsKit

@Suite("FetchHIGTool Tests")
struct FetchHIGToolTests {
    @Test("FetchHIGTool uses injected fetcher")
    func toolUsesFetcher() async throws {
        let session = MockNetworkSession()
        let path = "design/human-interface-guidelines/navigation"
        let url = try #require(URLHelpers.dataURL(for: path))
        let content = DocCHelpers.content(title: "HIG Tool")
        let data = try JSONEncoder().encode(content)
        session.setResponse(for: url, data: data, response: MockPayloads.httpResponse(url: url))
        let fetcher = HIGFetcher(api: AppleJSONAPI(session: session))
        let tool = FetchHIGTool(fetcher: fetcher)

        let result = try await tool.run(topic: "navigation")
        #expect(result.contains("# HIG Tool"))
    }
}
