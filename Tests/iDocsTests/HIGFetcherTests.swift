import Testing
import Foundation
@testable import iDocsKit

@Suite("HIGFetcher Tests")
struct HIGFetcherTests {
    @Test("HIGFetcher returns rendered DocC content when API succeeds")
    func fetchHIGViaAPI() async throws {
        let session = MockNetworkSession()
        let path = "design/human-interface-guidelines/navigation"
        let url = try #require(URLHelpers.dataURL(for: path))
        let content = DocCHelpers.content(title: "HIG")
        let data = try JSONEncoder().encode(content)
        session.setResponse(for: url, data: data, response: MockPayloads.httpResponse(url: url))

        let fetcher = HIGFetcher(api: AppleJSONAPI(session: session))
        let result = try await fetcher.fetch(topic: "navigation")
        #expect(result.contains("# HIG"))
    }

    @Test("HIGFetcher falls back to placeholder on failure")
    func fetchHIGFallback() async throws {
        let session = MockNetworkSession(stubbedError: MockError.networkTimeout)
        let fetcher = HIGFetcher(api: AppleJSONAPI(session: session))
        let result = try await fetcher.fetch(topic: "navigation")
        #expect(result.contains("Fallback/Placeholder"))
    }
}
