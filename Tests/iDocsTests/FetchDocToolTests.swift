import Testing
import Foundation
@testable import iDocsKit

@Suite("FetchDocTool Tests")
struct FetchDocToolTests {
    private let cacheDirectory = URL(fileURLWithPath: "/tmp/DocumentationCache", isDirectory: true)

    @Test("FetchDocTool returns cached content from disk")
    func diskCacheHit() async throws {
        let mockFS = MockFileSystem()
        let diskCache = DiskCache(name: "docs-test", fileManager: mockFS)
        let content = DocCHelpers.content(title: "Cached")
        let data = try JSONEncoder().encode(content)
        try await diskCache.set("/documentation/swiftui/view", value: data, ttl: 3600)

        let api = AppleJSONAPI(session: MockNetworkSession(stubbedError: MockError.networkTimeout))
        let tool = FetchDocTool(
            api: api,
            xcodeDocs: XcodeLocalDocs(fileManager: mockFS, searchProvider: MockSearchProvider(), cacheDirectory: cacheDirectory),
            diskCache: diskCache
        )
        let markdown = try await tool.run(path: "/documentation/swiftui/view")

        #expect(markdown.contains("# Cached"))
    }

    @Test("FetchDocTool falls back to local Xcode docs")
    func localXcodeHit() async throws {
        let mockFS = MockFileSystem()
        let searchProvider = MockSearchProvider()
        let xcodeDocs = XcodeLocalDocs(fileManager: mockFS, searchProvider: searchProvider, cacheDirectory: cacheDirectory)
        mockFS.virtualFiles[xcodeDocs.cacheDirectory.path] = Data()

        let sdkDir = xcodeDocs.cacheDirectory.appendingPathComponent("TestSDK")
        let sdkDirPath = sdkDir.path + "/"
        mockFS.virtualFiles[sdkDirPath] = Data()
        mockFS.virtualFiles[sdkDir.appendingPathComponent("documentation").path + "/"] = Data()

        let path = "/documentation/swiftui/view"
        let content = DocCHelpers.content(title: "Local")
        let docPath = sdkDir.appendingPathComponent("documentation/\(path).json")
        mockFS.virtualFiles[docPath.path] = try JSONEncoder().encode(content)

        let diskCache = DiskCache(name: "docs-test-local", fileManager: mockFS)
        let api = AppleJSONAPI(session: MockNetworkSession(stubbedError: MockError.networkTimeout))
        let tool = FetchDocTool(api: api, xcodeDocs: xcodeDocs, diskCache: diskCache)
        let output = try await tool.runDetailed(path: path)

        #expect(output.source == .local)
        #expect(output.markdown.contains("# Local"))
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

        let tool = FetchDocTool(
            api: api,
            xcodeDocs: XcodeLocalDocs(fileManager: mockFS, searchProvider: MockSearchProvider(), cacheDirectory: cacheDirectory),
            diskCache: diskCache
        )
        let markdown = try await tool.run(path: "/documentation/swiftui/view")

        #expect(markdown.contains("# Remote"))
    }

    @Test("FetchDocTool falls back to sosumi markdown when apple remote fails")
    func sosumiFallback() async throws {
        let mockFS = MockFileSystem()
        let diskCache = DiskCache(name: "docs-test-sosumi", fileManager: mockFS)

        let apple = AppleJSONAPI(session: MockNetworkSession(stubbedError: MockError.networkTimeout))

        let sosumiSession = MockNetworkSession()
        let sosumiURL = try #require(URLHelpers.sosumiFetchURL(for: "/documentation/swiftui/view"))
        let markdown = "# Sosumi View\n\nRendered markdown fallback."
        sosumiSession.setResponse(
            for: sosumiURL,
            data: Data(markdown.utf8),
            response: MockPayloads.httpResponse(url: sosumiURL)
        )
        let sosumi = SosumiAPI(session: sosumiSession)

        let tool = FetchDocTool(
            api: apple,
            sosumiAPI: sosumi,
            xcodeDocs: XcodeLocalDocs(fileManager: mockFS, searchProvider: MockSearchProvider(), cacheDirectory: cacheDirectory),
            diskCache: diskCache
        )
        let output = try await tool.runDetailed(path: "/documentation/swiftui/view")

        #expect(output.source == .sosumi)
        #expect(output.markdown.contains("# Sosumi View"))
    }
}
