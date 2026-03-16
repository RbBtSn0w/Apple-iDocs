import Testing
import Foundation
@testable import iDocsKit

@Suite("Network Tool Integration Tests", .enabled(if: IntegrationTestGate.isEnabled))
struct NetworkToolTests {
    @Test("Live search endpoint returns results")
    func liveSearch() async throws {
        let api = AppleJSONAPI()
        do {
            let results = try await api.search(query: "View")
            #expect(!results.isEmpty)
        } catch {
            let url = URLHelpers.searchURL(query: "View")?.absoluteString ?? "unknown"
            Issue.record("Live search failed. URL: \(url) Error: \(error)")
            throw error
        }
    }

    @Test("Live technologies endpoint returns results")
    func liveTechnologies() async throws {
        let tool = BrowseTechnologiesTool()
        do {
            let output = try await tool.run()
            #expect(!output.isEmpty)
        } catch {
            let url = URLHelpers.technologiesURL()?.absoluteString ?? "unknown"
            Issue.record("Live technologies failed. URL: \(url) Error: \(error)")
            throw error
        }
    }

    @Test("Network unavailable diagnostics")
    func networkUnavailableDiagnostics() async {
        let session = MockNetworkSession(stubbedError: URLError(.notConnectedToInternet))
        let api = AppleJSONAPI(session: session)
        do {
            _ = try await api.search(query: "View")
            Issue.record("Expected network error but request succeeded")
        } catch {
            #expect(true)
        }
    }
}
