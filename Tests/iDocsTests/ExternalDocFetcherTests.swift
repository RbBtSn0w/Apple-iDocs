import Testing
import Foundation
@testable import iDocsKit

@Suite("External DocC Fetcher Unit Tests")
struct ExternalDocFetcherTests {
    @Test("Fetch external DocC JSON with mock session")
    func fetchExternalDocWithMock() async throws {
        let url = URL(string: "https://example.com/documentation/example")!
        let dataURL = URL(string: "https://example.com/data/documentation/example.json")!
        let session = MockNetworkSession()
        session.setResponse(for: dataURL, data: MockPayloads.externalDocCJSON, response: MockPayloads.httpResponse(url: dataURL))

        let fetcher = ExternalDocCFetcher(session: session)
        let doc = try await fetcher.fetch(url: url)
        #expect(doc.metadata.title == "Example")
    }
}
