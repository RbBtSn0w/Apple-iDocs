import Testing
import Foundation
import MCP
import iDocsAdapter
@testable import iDocsMCPApp

@Suite("Adapter Integration Tests")
struct AdapterIntegrationTests {
    @Test("iDocsServer search_docs uses injected adapter")
    func searchUsesInjectedAdapter() async {
        let mock = MockDocumentationAdapter(
            searchResults: [SearchResult(id: "/documentation/swiftui/view", title: "View", snippet: "UI", technology: "swiftui")]
        )
        let server = iDocsServer(adapter: mock, config: DocumentationConfig(cachePath: "/tmp/idocs-tests"))

        let result = await server.handleToolCall(name: "search_docs", arguments: ["query": .string("View")])
        #expect(result.isError == false)
        #expect(String(describing: result.content).contains("View"))
        #expect(String(describing: result.content).contains("swiftui"))
    }

    @Test("iDocsServer fetch_doc returns mapped error from adapter")
    func fetchErrorFromAdapter() async {
        let mock = MockDocumentationAdapter(errorToThrow: .notFound(id: "/documentation/missing"))
        let server = iDocsServer(adapter: mock, config: DocumentationConfig(cachePath: "/tmp/idocs-tests"))

        let result = await server.handleToolCall(name: "fetch_doc", arguments: ["path": .string("/documentation/missing")])
        #expect(result.isError == true)
        #expect(String(describing: result.content).contains("could not be found"))
    }

    @Test("iDocsServer accepts custom injected config with mock adapter")
    func configInjectionAccepted() async throws {
        let mock = MockDocumentationAdapter(searchResults: [])
        let config = DocumentationConfig(cachePath: "/tmp/custom-cache-path", enableFileLocking: true)
        let server = iDocsServer(adapter: mock, config: config)

        let result = await server.handleToolCall(name: "search_docs", arguments: ["query": .string("Any")])
        #expect(result.isError == false)
    }

    @Test("DefaultDocumentationAdapter fails on major version mismatch")
    func versionMismatchFailure() {
        #expect(throws: DocumentationError.self) {
            _ = try DefaultDocumentationAdapter(adapterVersion: "2.0.0")
        }
    }
}
