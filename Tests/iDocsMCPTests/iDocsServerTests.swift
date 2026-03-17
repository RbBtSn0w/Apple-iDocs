import Testing
import Foundation
import MCP
import iDocsAdapter
@testable import iDocsMCPApp

@Suite("iDocsServer Tests")
struct iDocsServerTests {
    @Test("formatSearchResults returns empty message")
    func formatSearchResultsEmpty() async {
        let server = iDocsServer()
        let output = await server.formatSearchResults([])
        #expect(output.contains("No matching documentation"))
    }

    @Test("formatSearchResults includes result details")
    func formatSearchResultsNonEmpty() async {
        let server = iDocsServer()
        let results = [SearchResult(id: "/documentation/swiftui/view", title: "View", snippet: "UI", technology: "swiftui")]
        let output = await server.formatSearchResults(results)
        #expect(output.contains("View"))
        #expect(output.contains("/documentation/swiftui/view"))
        #expect(output.contains("swiftui"))
    }

    @Test("handleToolCall reports missing parameters")
    func handleToolCallMissingArgs() async {
        let server = iDocsServer()

        let missingQuery = await server.handleToolCall(name: "search_docs", arguments: nil)
        #expect(missingQuery.isError == true)

        let missingPath = await server.handleToolCall(name: "fetch_doc", arguments: nil)
        #expect(missingPath.isError == true)

        let missingTopic = await server.handleToolCall(name: "fetch_hig", arguments: nil)
        #expect(missingTopic.isError == true)

        let missingUrl = await server.handleToolCall(name: "fetch_external_doc", arguments: nil)
        #expect(missingUrl.isError == true)

        let missingVideo = await server.handleToolCall(name: "fetch_video_transcript", arguments: nil)
        #expect(missingVideo.isError == true)
    }

    @Test("handleToolCall returns unknown tool error")
    func handleToolCallUnknownTool() async {
        let server = iDocsServer()
        let result = await server.handleToolCall(name: "does_not_exist", arguments: nil)
        #expect(result.isError == true)
    }
}
