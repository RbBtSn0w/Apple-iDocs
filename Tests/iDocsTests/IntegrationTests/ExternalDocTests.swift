import Testing
import Foundation
@testable import iDocsKit

@Suite("External DocC Tests")
struct ExternalDocTests {
    
    @Test("Fetch external DocC JSON (mock)")
    func fetchExternalDocMock() async throws {
        let url = URL(string: "https://example.com/documentation/example")!
        let dataURL = URL(string: "https://example.com/data/documentation/example.json")!
        let session = MockNetworkSession()
        session.setResponse(for: dataURL, data: MockPayloads.externalDocCJSON, response: MockPayloads.httpResponse(url: dataURL))

        let fetcher = ExternalDocCFetcher(session: session)
        let doc = try await fetcher.fetch(url: url)
        #expect(doc.metadata.title == "Example")
    }

    @Test("Fetch external DocC JSON (live)", .enabled(if: IntegrationTestGate.isEnabled))
    func fetchExternalDocLive() async throws {
        let fetcher = ExternalDocCFetcher()
        let url = URL(string: "https://swiftpackageindex.com/apple/swift-algorithms/documentation/algorithms/chain")!
        do {
            let doc = try await fetcher.fetch(url: url)
            #expect(!doc.metadata.title.isEmpty)
        } catch {
            Issue.record("External DocC live fetch failed. URL: \(url.absoluteString) Error: \(error)")
            throw error
        }
    }
}
