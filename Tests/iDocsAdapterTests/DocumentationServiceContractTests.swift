import Testing
import Foundation
@testable import iDocsAdapter

@Suite("iDocsAdapter Contract Tests")
struct DocumentationServiceContractTests {
    @Test("DocumentationConfig supports explicit injection values")
    func configInjection() {
        let config = DocumentationConfig(
            cachePath: "/tmp/idocs-tests",
            locale: Locale(identifier: "en_US"),
            timeout: 12,
            apiBaseURL: URL(string: "https://example.com")!,
            enableFileLocking: true
        )

        #expect(config.cachePath == "/tmp/idocs-tests")
        #expect(config.timeout == 12)
        #expect(config.apiBaseURL.absoluteString == "https://example.com")
        #expect(config.enableFileLocking)
    }

    @Test("Default CLI config provides cache path")
    func defaultCLIConfig() {
        let config = DocumentationConfig.cliDefault()
        #expect(config.cachePath.contains("iDocs"))
    }

    @Test("DocumentationService exposes async API shape")
    func asyncAPIShape() async throws {
        struct StubService: DocumentationService {
            func search(query: String, config: DocumentationConfig) async throws -> [SearchResult] { [] }
            func fetch(id: String, config: DocumentationConfig) async throws -> DocumentationContent {
                DocumentationContent(title: id, body: "", url: URL(string: "https://example.com")!)
            }
            func listTechnologies(config: DocumentationConfig) async throws -> [Technology] { [] }
            func getCoreVersion() -> String { "1.0.0" }
        }

        let service = StubService()
        let config = DocumentationConfig(cachePath: "/tmp")

        let search = try await service.search(query: "SwiftUI", config: config)
        let fetch = try await service.fetch(id: "/documentation/swiftui/view", config: config)
        let list = try await service.listTechnologies(config: config)

        #expect(search.isEmpty)
        #expect(fetch.title == "/documentation/swiftui/view")
        #expect(list.isEmpty)
    }

    @Test("SearchResult source field is preserved through adapter contract")
    func searchResultSourceRoundTrip() async throws {
        let expected = SearchResult(
            id: "/documentation/swiftui/view",
            title: "View",
            snippet: "A view",
            technology: "swiftui",
            source: .sosumi
        )

        let service = MockDocumentationAdapter(searchResults: [expected])
        let config = DocumentationConfig(cachePath: "/tmp")
        let results = try await service.search(query: "View", config: config)

        #expect(results.count == 1)
        #expect(results[0].source == .sosumi)
    }
}
