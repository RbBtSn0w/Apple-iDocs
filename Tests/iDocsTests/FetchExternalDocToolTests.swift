import Testing
import Foundation
@testable import iDocsKit

@Suite("FetchExternalDocTool Tests")
struct FetchExternalDocToolTests {
    @Test("FetchExternalDocTool rejects invalid URL")
    func invalidURL() async throws {
        let tool = FetchExternalDocTool(fetcher: ExternalDocCFetcher(session: MockNetworkSession()))
        let result = try await tool.run(url: "")
        #expect(result.contains("Invalid URL"))
    }

    @Test("FetchExternalDocTool renders external DocC content")
    func rendersExternalDoc() async throws {
        let url = URL(string: "https://example.com/documentation/example")!
        let dataURL = URL(string: "https://example.com/data/documentation/example.json")!
        let session = MockNetworkSession()
        let content = DocCHelpers.content(title: "External")
        let data = try JSONEncoder().encode(content)
        session.setResponse(for: dataURL, data: data, response: MockPayloads.httpResponse(url: dataURL))
        let fetcher = ExternalDocCFetcher(session: session)
        let tool = FetchExternalDocTool(fetcher: fetcher)

        let result = try await tool.run(url: url.absoluteString)
        #expect(result.contains("# External"))
    }
}
