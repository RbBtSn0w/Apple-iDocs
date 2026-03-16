import Testing
import Foundation
@testable import iDocsKit

@Suite("XcodeDocsTool Tests")
struct XcodeDocsToolTests {
    @Test("XcodeDocsTool list mode shows empty message")
    func listModeEmpty() async throws {
        let mockFS = MockFileSystem()
        let dataSource = XcodeLocalDocs(fileManager: mockFS, searchProvider: MockSearchProvider())
        mockFS.virtualFiles[dataSource.cacheDirectory.path] = Data()

        let tool = XcodeDocsTool(dataSource: dataSource)
        let result = try await tool.run(list: true)
        #expect(result.contains("No Xcode documentation sets found locally"))
    }

    @Test("XcodeDocsTool search mode without query")
    func searchMissingQuery() async throws {
        let tool = XcodeDocsTool(dataSource: XcodeLocalDocs(fileManager: MockFileSystem(), searchProvider: MockSearchProvider()))
        let result = try await tool.run(query: nil, list: false)
        #expect(result.contains("Missing query parameter"))
    }

    // List mode with real SDKs uses file system metadata; tested elsewhere in integration tests.
}
