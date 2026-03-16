import Testing
import Foundation
@testable import iDocsKit

@Suite("FetchDocTool Tests")
struct FetchDocToolTests {
    @Test("FetchDocTool returns cached content from disk")
    func diskCacheHit() async throws {
        let mockFS = MockFileSystem()
        let diskCache = DiskCache(name: "docs-test", fileManager: mockFS)
        let content = DocCHelpers.content(title: "Cached")
        let data = try JSONEncoder().encode(content)
        try await diskCache.set("/documentation/swiftui/view", value: data, ttl: 3600)

        let api = AppleJSONAPI(session: MockNetworkSession(stubbedError: MockError.networkTimeout))
        let tool = FetchDocTool(api: api, xcodeDocs: XcodeLocalDocs(fileManager: mockFS, searchProvider: MockSearchProvider()), diskCache: diskCache)
        let markdown = try await tool.run(path: "/documentation/swiftui/view")

        #expect(markdown.contains("# Cached"))
    }

    @Test("FetchDocTool falls back to local Xcode docs")
    func localXcodeHit() async throws {
        let mockFS = MockFileSystem()
        let searchProvider = MockSearchProvider()
        let xcodeDocs = XcodeLocalDocs(fileManager: mockFS, searchProvider: searchProvider)
        mockFS.virtualFiles[xcodeDocs.cacheDirectory.path] = Data()

        let sdkDir = xcodeDocs.cacheDirectory.appendingPathComponent("TestSDK")
        let sdkDirPath = sdkDir.path + "/"
        mockFS.virtualFiles[sdkDirPath] = Data()

        let path = "/documentation/swiftui/view"
        let content = DocCHelpers.content(title: "Local")
        let docPath = sdkDir.appendingPathComponent("documentation/\(path).json")
        mockFS.virtualFiles[docPath.path] = try JSONEncoder().encode(content)

        let diskCache = DiskCache(name: "docs-test-local", fileManager: mockFS)
        let api = AppleJSONAPI(session: MockNetworkSession(stubbedError: MockError.networkTimeout))
        let tool = FetchDocTool(api: api, xcodeDocs: xcodeDocs, diskCache: diskCache)
        let markdown = try await tool.run(path: path)

        #expect(markdown.contains("# Local"))
    }

    @Test("FetchDocTool fetches from remote API when cache and local miss")
    func remoteFallback() async throws {
        let mockFS = MockFileSystem()
        let diskCache = DiskCache(name: "docs-test-remote", fileManager: mockFS)

        let content = DocCHelpers.content(title: "Remote")
        let data = try JSONEncoder().encode(content)
        let session = MockNetworkSession()
        let url = try #require(URLHelpers.dataURL(for: "/documentation/swiftui/view"))
        session.setResponse(for: url, data: data, response: MockPayloads.httpResponse(url: url))
        let api = AppleJSONAPI(session: session)

        let tool = FetchDocTool(api: api, xcodeDocs: XcodeLocalDocs(fileManager: mockFS, searchProvider: MockSearchProvider()), diskCache: diskCache)
        let markdown = try await tool.run(path: "/documentation/swiftui/view")

        #expect(markdown.contains("# Remote"))
    }
}
