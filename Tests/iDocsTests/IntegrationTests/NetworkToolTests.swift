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
        } catch let error as URLError {
            #expect(error.code == .notConnectedToInternet)
        } catch {
            Issue.record("Expected URLError.notConnectedToInternet but received: \(error)")
        }
    }

    @Test("Fallback diagnostics: apple failure then sosumi success")
    func fallbackDiagnostics() async throws {
        let appleSession = MockNetworkSession()
        let appleURL = try #require(URLHelpers.searchURL(query: "FallbackCase"))
        appleSession.setResponse(
            for: appleURL,
            data: Data(),
            response: MockPayloads.httpResponse(url: appleURL, statusCode: 404)
        )

        let sosumiSession = MockNetworkSession()
        let sosumiURL = try #require(URLHelpers.sosumiSearchURL(query: "FallbackCase"))
        sosumiSession.setResponse(
            for: sosumiURL,
            data: MockPayloads.sosumiSearchJSON,
            response: MockPayloads.httpResponse(url: sosumiURL)
        )

        let tool = SearchDocsTool(
            api: AppleJSONAPI(session: appleSession),
            sosumiAPI: SosumiAPI(session: sosumiSession),
            xcodeDocs: XcodeLocalDocs(fileManager: MockFileSystem(), searchProvider: MockSearchProvider()),
            memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5)
        )

        let results = try await tool.run(query: "FallbackCase")
        #expect(!results.isEmpty)
        #expect(results.first?.source == .sosumi)
    }

    @Test("Live fetch release notes renders DocC list items and tables without dropped content")
    func liveFetchReleaseNotesListItems() async throws {
        let tool = FetchDocTool()
        let markdown = try await tool.run(path: "/documentation/xcode-release-notes/xcode-27-release-notes")
        #expect(markdown.contains("- "), "Rendered markdown should contain bullet list items")
        #expect(markdown.contains("Localization"), "Rendered markdown should contain Localization section")
    }

    @Test("Live search recalls Xcode guide articles and bounds duplicate technologies")
    func liveSearchXcodeGuides() async throws {
        let api = AppleJSONAPI()
        let results = try await api.search(query: "localizing your app using agents")
        #expect(!results.isEmpty)
        #expect(results.count <= 50, "Results should be capped at 50")
        #expect(results.contains { $0.path == "/documentation/xcode/localizing-your-app-using-agents" }, "Should recall agent localization article")

        let techCount = results.filter { $0.path == "/documentation/technologies" }.count
        #expect(techCount <= 1, "Should not duplicate technologies breadcrumb")
    }

    @Test("Live search recalls Xcode String Catalog articles")
    func liveSearchStringCatalog() async throws {
        let api = AppleJSONAPI()
        let results = try await api.search(query: "String Catalog")
        #expect(!results.isEmpty)
        #expect(results.count <= 50, "Results should be capped at 50")
        #expect(results.contains { $0.path.contains("catalog") }, "Should recall catalog articles")
    }
}
