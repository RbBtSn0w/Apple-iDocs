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

    @Test("FetchDocTool fetches App Store Connect Help HTML as markdown")
    func appStoreConnectHelpFetch() async throws {
        let mockFS = MockFileSystem()
        let diskCache = DiskCache(name: "docs-test-help", fileManager: mockFS)
        let paths = [
            "/help/app-store-connect/manage-builds/upload-builds",
            "/help/app-store-connect/test-a-beta-version/testflight-overview"
        ]

        let helpSession = MockNetworkSession()
        for path in paths {
            let helpURL = try #require(URLHelpers.appleHelpURL(for: path))
            helpSession.setResponse(
                for: helpURL,
                data: MockPayloads.appStoreConnectHelpHTML,
                response: MockPayloads.httpResponse(url: helpURL, contentType: "text/html")
            )
        }

        let tool = FetchDocTool(
            api: AppleJSONAPI(session: MockNetworkSession(stubbedError: MockError.networkTimeout)),
            sosumiAPI: SosumiAPI(session: MockNetworkSession(stubbedError: MockError.networkTimeout)),
            helpAPI: AppleHelpAPI(session: helpSession),
            xcodeDocs: XcodeLocalDocs(fileManager: mockFS, searchProvider: MockSearchProvider(), cacheDirectory: cacheDirectory),
            diskCache: diskCache
        )

        for path in paths {
            let output = try await tool.runDetailed(path: path)

            #expect(output.source == .help)
            #expect(output.markdown.contains("# Upload builds"))
            #expect(output.markdown.contains("Before you begin"))
            let titleRange = try #require(output.markdown.range(of: "Upload builds"))
            let headingRange = try #require(output.markdown.range(of: "Before you begin"))
            let bodyRange = try #require(output.markdown.range(of: "Make sure your app record is configured."))
            #expect(titleRange.lowerBound < headingRange.lowerBound)
            #expect(headingRange.lowerBound < bodyRange.lowerBound)
            #expect(output.sourceAttempts.map(\.source) == [.cache, .local, .help])
            #expect(output.sourceAttempts.last?.status == .hit)
        }
    }

    @Test("FetchDocTool falls back to sosumi after Help errors")
    func helpFetchErrorFallsBackToSosumi() async throws {
        let mockFS = MockFileSystem()
        let diskCache = DiskCache(name: "docs-test-help-fallback", fileManager: mockFS)
        let path = "/help/app-store-connect/manage-builds/upload-builds"

        let helpSession = MockNetworkSession()
        let helpURL = try #require(URLHelpers.appleHelpURL(for: path))
        helpSession.setResponse(
            for: helpURL,
            data: Data("temporary error".utf8),
            response: MockPayloads.httpResponse(url: helpURL, statusCode: 503, contentType: "text/html")
        )

        let sosumiSession = MockNetworkSession()
        let sosumiURL = try #require(URLHelpers.sosumiFetchURL(for: path))
        sosumiSession.setResponse(
            for: sosumiURL,
            data: Data("# Upload builds\n\nFallback Help content.".utf8),
            response: MockPayloads.httpResponse(url: sosumiURL, contentType: "text/markdown")
        )

        let tool = FetchDocTool(
            api: AppleJSONAPI(session: MockNetworkSession(stubbedError: MockError.networkTimeout)),
            sosumiAPI: SosumiAPI(session: sosumiSession),
            helpAPI: AppleHelpAPI(session: helpSession),
            xcodeDocs: XcodeLocalDocs(fileManager: mockFS, searchProvider: MockSearchProvider(), cacheDirectory: cacheDirectory),
            diskCache: diskCache
        )

        let output = try await tool.runDetailed(path: path)

        #expect(output.source == .sosumi)
        #expect(output.sourceAttempts.map(\.source) == [.cache, .local, .help, .sosumi])
        #expect(output.sourceAttempts.first { $0.source == .help }?.reason == "http_503")
        #expect(output.sourceAttempts.first { $0.source == .help }?.statusCode == 503)
        #expect(output.sourceAttempts.last?.status == .hit)
    }

    @Test("FetchDocTool records invalid Help response before fallback")
    func helpInvalidResponseDiagnostic() async throws {
        let mockFS = MockFileSystem()
        let diskCache = DiskCache(name: "docs-test-help-invalid-response", fileManager: mockFS)
        let path = "/help/app-store-connect/test-a-beta-version/testflight-overview"

        let helpSession = MockNetworkSession()
        let helpURL = try #require(URLHelpers.appleHelpURL(for: path))
        helpSession.setResponse(
            for: helpURL,
            data: Data(),
            response: URLResponse(url: helpURL, mimeType: "text/html", expectedContentLength: 0, textEncodingName: "utf-8")
        )

        let sosumiSession = MockNetworkSession()
        let sosumiURL = try #require(URLHelpers.sosumiFetchURL(for: path))
        sosumiSession.setResponse(
            for: sosumiURL,
            data: Data("# TestFlight overview\n\nFallback Help content.".utf8),
            response: MockPayloads.httpResponse(url: sosumiURL, contentType: "text/markdown")
        )

        let tool = FetchDocTool(
            api: AppleJSONAPI(session: MockNetworkSession(stubbedError: MockError.networkTimeout)),
            sosumiAPI: SosumiAPI(session: sosumiSession),
            helpAPI: AppleHelpAPI(session: helpSession),
            xcodeDocs: XcodeLocalDocs(fileManager: mockFS, searchProvider: MockSearchProvider(), cacheDirectory: cacheDirectory),
            diskCache: diskCache
        )

        let output = try await tool.runDetailed(path: path)

        #expect(output.source == .sosumi)
        #expect(output.sourceAttempts.first { $0.source == .help }?.reason == "invalid_response")
    }

    @Test("FetchDocTool rejects unsupported real Apple page families without NOT_FOUND")
    func unsupportedApplePageFamily() async throws {
        let tool = FetchDocTool(
            api: AppleJSONAPI(session: MockNetworkSession(stubbedError: MockError.networkTimeout)),
            sosumiAPI: SosumiAPI(session: MockNetworkSession(stubbedError: MockError.networkTimeout)),
            xcodeDocs: XcodeLocalDocs(fileManager: MockFileSystem(), searchProvider: MockSearchProvider(), cacheDirectory: cacheDirectory),
            diskCache: DiskCache(name: "docs-test-unsupported", fileManager: MockFileSystem())
        )

        for path in ["/videos/play/wwdc2024/10123", "/news", "/app-store-connect/api"] {
            do {
                _ = try await tool.runDetailed(path: path)
                Issue.record("Expected unsupported source type for \(path).")
            } catch let error as iDocsError {
                #expect(error.reason == "unsupported_source_type")
                #expect(error.fetchAttempts.map(\.reason).contains("unsupported_source_type"))
            }
        }
    }

    @Test("FetchDocTool records corrupt cache and local decode failures")
    func corruptCacheAndLocalErrorsAreDiagnosticAttempts() async throws {
        let mockFS = MockFileSystem()
        let diskCache = DiskCache(name: "docs-test-corrupt-cache", fileManager: mockFS)
        let path = "/documentation/swiftui/view"
        try await diskCache.set(path, value: Data([0xff, 0xfe, 0xfd]), ttl: 3600)

        let xcodeDocs = XcodeLocalDocs(fileManager: mockFS, searchProvider: MockSearchProvider(), cacheDirectory: cacheDirectory)
        mockFS.virtualFiles[xcodeDocs.cacheDirectory.path] = Data()
        let sdkDir = xcodeDocs.cacheDirectory.appendingPathComponent("TestSDK")
        mockFS.virtualFiles[sdkDir.path + "/"] = Data()
        mockFS.virtualFiles[sdkDir.appendingPathComponent("documentation").path + "/"] = Data()
        mockFS.virtualFiles[sdkDir.appendingPathComponent("documentation/\(path).json").path] = Data("{\"not\":\"docc\"}".utf8)

        let appleSession = MockNetworkSession()
        let appleURL = try #require(URLHelpers.dataURL(for: path))
        appleSession.setResponse(
            for: appleURL,
            data: MockPayloads.docCJSON(title: "Remote View", identifier: "doc://view", abstract: "Remote content."),
            response: MockPayloads.httpResponse(url: appleURL)
        )

        let tool = FetchDocTool(
            api: AppleJSONAPI(session: appleSession),
            xcodeDocs: xcodeDocs,
            diskCache: diskCache
        )

        let output = try await tool.runDetailed(path: path)

        #expect(output.source == .apple)
        #expect(output.sourceAttempts.map(\.source) == [.cache, .local, .apple])
        #expect(output.sourceAttempts.first { $0.source == .cache }?.reason == "corrupt_cache_entry")
        #expect(output.sourceAttempts.first { $0.source == .local }?.reason == "local_decode_failed")
    }

    @Test("FetchDocTool records primary decode failure and successful fallback")
    func fetchFallbackProvenance() async throws {
        let mockFS = MockFileSystem()
        let diskCache = DiskCache(name: "docs-test-provenance", fileManager: mockFS)
        let paths = [
            "/documentation/xcode/creating-a-workflow-that-builds-your-app-for-distribution",
            "/documentation/xcode/developing-a-workflow-strategy-for-xcode-cloud",
            "/documentation/xcode/environment-variable-reference"
        ]

        let appleSession = MockNetworkSession()
        let sosumiSession = MockNetworkSession()
        for path in paths {
            let appleURL = try #require(URLHelpers.dataURL(for: path))
            appleSession.setResponse(
                for: appleURL,
                data: Data("{\"not\":\"docc\"}".utf8),
                response: MockPayloads.httpResponse(url: appleURL)
            )

            let sosumiURL = try #require(URLHelpers.sosumiFetchURL(for: path))
            sosumiSession.setResponse(
                for: sosumiURL,
                data: Data("# Environment variable reference\n\nFallback content.".utf8),
                response: MockPayloads.httpResponse(url: sosumiURL, contentType: "text/markdown")
            )
        }

        let tool = FetchDocTool(
            api: AppleJSONAPI(session: appleSession),
            sosumiAPI: SosumiAPI(session: sosumiSession),
            xcodeDocs: XcodeLocalDocs(fileManager: mockFS, searchProvider: MockSearchProvider(), cacheDirectory: cacheDirectory),
            diskCache: diskCache
        )

        for path in paths {
            let output = try await tool.runDetailed(path: path)

            #expect(output.source == .sosumi)
            #expect(output.sourceAttempts.map(\.source) == [.cache, .local, .apple, .sosumi])
            #expect(output.sourceAttempts.first { $0.source == .apple }?.reason == "remote_decode_failed")
            #expect(output.sourceAttempts.last?.status == .hit)
        }
    }

    @Test("FetchDocTool records Apple HTTP status before successful fallback")
    func appleHTTPStatusCodeInFallbackDiagnostics() async throws {
        let mockFS = MockFileSystem()
        let diskCache = DiskCache(name: "docs-test-apple-status", fileManager: mockFS)
        let path = "/documentation/swiftui/view"

        let appleSession = MockNetworkSession()
        let appleURL = try #require(URLHelpers.dataURL(for: path))
        appleSession.setResponse(
            for: appleURL,
            data: Data("service unavailable".utf8),
            response: MockPayloads.httpResponse(url: appleURL, statusCode: 503)
        )

        let sosumiSession = MockNetworkSession()
        let sosumiURL = try #require(URLHelpers.sosumiFetchURL(for: path))
        sosumiSession.setResponse(
            for: sosumiURL,
            data: Data("# View\n\nFallback content.".utf8),
            response: MockPayloads.httpResponse(url: sosumiURL, contentType: "text/markdown")
        )

        let tool = FetchDocTool(
            api: AppleJSONAPI(session: appleSession),
            sosumiAPI: SosumiAPI(session: sosumiSession),
            xcodeDocs: XcodeLocalDocs(fileManager: mockFS, searchProvider: MockSearchProvider(), cacheDirectory: cacheDirectory),
            diskCache: diskCache
        )

        let output = try await tool.runDetailed(path: path)

        #expect(output.source == .sosumi)
        #expect(output.sourceAttempts.first { $0.source == .apple }?.reason == "http_503")
        #expect(output.sourceAttempts.first { $0.source == .apple }?.statusCode == 503)
    }

    @Test("FetchDocTool aggregate failure includes ordered source attempts")
    func aggregateFetchFailureIncludesSourceAttempts() async throws {
        let mockFS = MockFileSystem()
        let diskCache = DiskCache(name: "docs-test-aggregate", fileManager: mockFS)
        let path = "/documentation/appstoreconnectapi"

        let appleSession = MockNetworkSession()
        let appleURL = try #require(URLHelpers.dataURL(for: path))
        appleSession.setResponse(
            for: appleURL,
            data: Data("{\"not\":\"docc\"}".utf8),
            response: MockPayloads.httpResponse(url: appleURL)
        )

        let sosumiSession = MockNetworkSession()
        let sosumiURL = try #require(URLHelpers.sosumiFetchURL(for: path))
        sosumiSession.setResponse(
            for: sosumiURL,
            data: Data("server error".utf8),
            response: MockPayloads.httpResponse(url: sosumiURL, statusCode: 500)
        )

        let tool = FetchDocTool(
            api: AppleJSONAPI(session: appleSession),
            sosumiAPI: SosumiAPI(session: sosumiSession),
            xcodeDocs: XcodeLocalDocs(fileManager: mockFS, searchProvider: MockSearchProvider(), cacheDirectory: cacheDirectory),
            diskCache: diskCache
        )

        do {
            _ = try await tool.runDetailed(path: path)
            Issue.record("Expected aggregate fetch failure.")
        } catch let error as iDocsError {
            #expect(error.fetchAttempts.map(\.source) == [.cache, .local, .apple, .sosumi])
            #expect(error.fetchAttempts.first { $0.source == .apple }?.reason == "remote_decode_failed")
            #expect(error.fetchAttempts.first { $0.source == .sosumi }?.reason == "http_500")
        }
    }
}
