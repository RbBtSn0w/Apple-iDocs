import Testing
import Foundation
@testable import iDocsKit

@Suite("SearchDocsTool Integration Tests")
struct ToolTests {

    private func makeMockAPI(queries: [String]) -> AppleJSONAPI {
        let session = MockNetworkSession()
        for query in queries {
            if let url = URLHelpers.searchURL(query: query) {
                let response = MockPayloads.httpResponse(url: url)
                session.setResponse(for: url, data: MockPayloads.searchJSON, response: response)
            }
        }
        if let techUrl = URLHelpers.technologiesURL() {
            let response = MockPayloads.httpResponse(url: techUrl)
            session.setResponse(for: techUrl, data: MockPayloads.technologiesJSON, response: response)
        }
        return AppleJSONAPI(session: session)
    }

    private func makeMockSosumiAPI(queries: [String]) -> SosumiAPI {
        let session = MockNetworkSession()
        for query in queries {
            if let url = URLHelpers.sosumiSearchURL(query: query) {
                let response = MockPayloads.httpResponse(url: url)
                session.setResponse(for: url, data: MockPayloads.sosumiSearchJSON, response: response)
            }
        }
        return SosumiAPI(session: session)
    }
    
    @Test("SearchDocsTool handles basic query")
    func searchToolBasic() async throws {
        let api = makeMockAPI(queries: ["View"])
        let sosumi = makeMockSosumiAPI(queries: ["View"])
        let tool = SearchDocsTool(api: api, sosumiAPI: sosumi, memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5))
        let result = try await tool.run(query: "View")
        
        #expect(!result.isEmpty)
        #expect(result.first?.title == "View")
    }
    
    @Test("SearchDocsTool handles wildcards")
    func searchToolWildcard() async throws {
        let api = makeMockAPI(queries: ["NS*Controller"])
        let sosumi = makeMockSosumiAPI(queries: ["NS*Controller"])
        let tool = SearchDocsTool(api: api, sosumiAPI: sosumi, memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5))
        let result = try await tool.run(query: "NS*Controller")
        
        #expect(!result.isEmpty)
        #expect(result.first?.source == .sosumi || result.first?.source == .apple)
    }
    
    @Test("BrowseTechnologiesTool lists technologies")
    func browseTechs() async throws {
        let api = makeMockAPI(queries: [])
        let tool = BrowseTechnologiesTool(api: api)
        let result = try await tool.run()
        #expect(!result.isEmpty)
        #expect(result.contains("SwiftUI"))
    }

    @Test("AppleJSONAPI parses search payload")
    func parseSearchPayload() async throws {
        let api = makeMockAPI(queries: ["View"])
        let results = try await api.search(query: "View")
        #expect(results.count == 1)
        #expect(results.first?.path == "/documentation/swiftui/view")
    }

    @Test("AppleJSONAPI recovers known issue pages through direct Apple lookup")
    func appleDirectLookupRecoversKnownIssuePages() async throws {
        let session = MockNetworkSession()
        let cases = [
            (
                query: "NavigationSplitView",
                title: "NavigationSplitView",
                path: "/documentation/swiftui/navigationsplitview",
                abstract: "A view that presents views in two or three columns."
            ),
            (
                query: "SwiftUI inspector isPresented inspectorColumnWidth",
                title: "inspectorColumnWidth(min:ideal:max:)",
                path: "/documentation/swiftui/view/inspectorcolumnwidth(min:ideal:max:)",
                abstract: "Sets a flexible preferred width for the inspector column."
            ),
            (
                query: "macOS split views inspector sidebar SwiftUI",
                title: "Split views",
                path: "/design/human-interface-guidelines/split-views",
                abstract: "A split view manages multiple adjacent panes of content."
            )
        ]

        for testCase in cases {
            let searchURL = try #require(URLHelpers.searchURL(query: testCase.query))
            session.setResponse(
                for: searchURL,
                data: MockPayloads.emptySearchJSON,
                response: MockPayloads.httpResponse(url: searchURL)
            )
            let dataURL = try #require(URLHelpers.dataURL(for: testCase.path))
            session.setResponse(
                for: dataURL,
                data: MockPayloads.docCJSON(
                    title: testCase.title,
                    identifier: "doc://com.apple.documentation\(testCase.path)",
                    abstract: testCase.abstract
                ),
                response: MockPayloads.httpResponse(url: dataURL)
            )
        }

        let api = AppleJSONAPI(session: session)

        for testCase in cases {
            let results = try await api.search(query: testCase.query)

            #expect(results.contains { $0.title == testCase.title && $0.path == testCase.path && $0.source == .apple })
        }
    }

    @Test("AppleJSONAPI preserves direct lookup transport failures")
    func appleDirectLookupPreservesTransportFailures() async throws {
        let session = MockNetworkSession()
        let query = "NavigationSplitView"
        let searchURL = try #require(URLHelpers.searchURL(query: query))
        session.setResponse(
            for: searchURL,
            data: MockPayloads.emptySearchJSON,
            response: MockPayloads.httpResponse(url: searchURL)
        )
        let dataURL = try #require(URLHelpers.dataURL(for: "/documentation/swiftui/navigationsplitview"))
        session.setError(for: dataURL, error: URLError(.notConnectedToInternet))

        let api = AppleJSONAPI(session: session)

        do {
            _ = try await api.search(query: query)
            Issue.record("Expected direct Apple lookup transport failure to be propagated.")
        } catch let error as URLError {
            #expect(error.code == .notConnectedToInternet)
        } catch {
            Issue.record("Expected URLError, got \(error).")
        }
    }

    @Test("AppleJSONAPI parses technologies payload")
    func parseTechnologiesPayload() async throws {
        let api = makeMockAPI(queries: [])
        let techs = try await api.fetchTechnologies()
        #expect(techs.count == 1)
        #expect(techs.first?.name == "SwiftUI")
    }

    @Test("AppleJSONAPI parses modern technologies payload")
    func parseModernTechnologiesPayload() async throws {
        let session = MockNetworkSession()
        if let techURL = URLHelpers.technologiesURL() {
            session.setResponse(
                for: techURL,
                data: MockPayloads.technologiesModernJSON,
                response: MockPayloads.httpResponse(url: techURL)
            )
        }

        let api = AppleJSONAPI(session: session)
        let techs = try await api.fetchTechnologies()
        #expect(techs.count == 1)
        #expect(techs.first?.name == "SwiftUI")
        #expect(techs.first?.url == "/documentation/swiftui")
    }

    @Test("SearchDocsTool falls back to sosumi when apple remote misses")
    func searchToolFallsBackToSosumi() async throws {
        let api = makeMockAPI(queries: ["NoLocalHit"])
        let sosumi = makeMockSosumiAPI(queries: ["NoLocalHit"])
        let tool = SearchDocsTool(api: api, sosumiAPI: sosumi, memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5))

        let result = try await tool.run(query: "NoLocalHit")
        #expect(!result.isEmpty)
        #expect(result.first?.source == .sosumi)
    }

    @Test("SearchDocsTool classifies mixed Apple page families and fetch support")
    func searchToolClassifiesMixedApplePageFamilies() async throws {
        let query = "Xcode Cloud TestFlight App Store Connect"
        let appleSession = MockNetworkSession()
        let appleURL = try #require(URLHelpers.searchURL(query: query))
        appleSession.setResponse(
            for: appleURL,
            data: MockPayloads.emptySearchJSON,
            response: MockPayloads.httpResponse(url: appleURL)
        )

        let sosumiSession = MockNetworkSession()
        let sosumiURL = try #require(URLHelpers.sosumiSearchURL(query: query))
        sosumiSession.setResponse(
            for: sosumiURL,
            data: MockPayloads.mixedSosumiSearchJSON,
            response: MockPayloads.httpResponse(url: sosumiURL)
        )

        let tool = SearchDocsTool(
            api: AppleJSONAPI(session: appleSession),
            sosumiAPI: SosumiAPI(session: sosumiSession),
            xcodeDocs: XcodeLocalDocs(fileManager: MockFileSystem(), searchProvider: MockSearchProvider()),
            memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5)
        )

        let output = try await tool.runDetailed(query: query)
        let byPath = Dictionary(uniqueKeysWithValues: output.results.map { ($0.path, $0) })

        #expect(byPath["/documentation/xcode/creating-a-workflow-that-builds-your-app-for-distribution"]?.sourceKind == .documentation)
        #expect(byPath["/documentation/xcode/creating-a-workflow-that-builds-your-app-for-distribution"]?.fetchSupported == true)
        #expect(byPath["/help/app-store-connect/manage-builds/upload-builds"]?.sourceKind == .help)
        #expect(byPath["/help/app-store-connect/manage-builds/upload-builds"]?.fetchSupported == true)
        #expect(byPath["/videos/play/wwdc2024/10123"]?.sourceKind == .video)
        #expect(byPath["/videos/play/wwdc2024/10123"]?.fetchSupported == false)
        #expect(byPath["/news"]?.sourceKind == .news)
        #expect(byPath["/news"]?.fetchSupported == false)
        #expect(byPath["/app-store-connect/api"]?.sourceKind == .marketing)
        #expect(byPath["/app-store-connect/api"]?.fetchSupported == false)
        #expect(output.results.allSatisfy { $0.queryAttempt == query })
    }

    @Test("SearchDocsTool preserves original and derived query attempts for broad fallback")
    func searchToolPreservesBroadQueryFallbackAttempt() async throws {
        let query = "How do I upload an Xcode Cloud build to TestFlight in App Store Connect?"
        let derivedQuery = "upload Xcode Cloud TestFlight App Store Connect"

        let appleSession = MockNetworkSession()
        let appleURL = try #require(URLHelpers.searchURL(query: query))
        appleSession.setResponse(
            for: appleURL,
            data: MockPayloads.emptySearchJSON,
            response: MockPayloads.httpResponse(url: appleURL)
        )

        let sosumiSession = MockNetworkSession()
        let originalSosumiURL = try #require(URLHelpers.sosumiSearchURL(query: query))
        sosumiSession.setResponse(
            for: originalSosumiURL,
            data: MockPayloads.emptySosumiSearchJSON,
            response: MockPayloads.httpResponse(url: originalSosumiURL)
        )
        let derivedSosumiURL = try #require(URLHelpers.sosumiSearchURL(query: derivedQuery))
        sosumiSession.setResponse(
            for: derivedSosumiURL,
            data: MockPayloads.mixedSosumiSearchJSON,
            response: MockPayloads.httpResponse(url: derivedSosumiURL)
        )

        let tool = SearchDocsTool(
            api: AppleJSONAPI(session: appleSession),
            sosumiAPI: SosumiAPI(session: sosumiSession),
            xcodeDocs: XcodeLocalDocs(fileManager: MockFileSystem(), searchProvider: MockSearchProvider()),
            memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5)
        )

        let output = try await tool.runDetailed(query: query)

        #expect(!output.results.isEmpty)
        #expect(output.results.allSatisfy { $0.queryAttempt == derivedQuery })
        #expect(output.instrumentation.stages.contains { $0.queryAttempt == query })
        #expect(output.instrumentation.stages.contains { $0.queryAttempt == derivedQuery })
    }

    @Test("SearchDocsTool continues remote search after local module fallback for composite symbol query")
    func searchToolContinuesRemoteAfterLocalModuleFallback() async throws {
        let query = "SwiftUI NavigationSplitView"
        let mockFS = MockFileSystem()
        let cacheDirectory = URL(fileURLWithPath: "/tmp/DocumentationCache", isDirectory: true)
        mockFS.virtualFiles[cacheDirectory.path + "/"] = Data()
        let sdkURL = cacheDirectory.appendingPathComponent("26.3")
        let docsRoot = sdkURL.appendingPathComponent("documentation", isDirectory: true)
        let moduleRoot = docsRoot.appendingPathComponent("SwiftUI", isDirectory: true)
        mockFS.virtualFiles[sdkURL.path + "/"] = Data()
        mockFS.virtualFiles[docsRoot.path + "/"] = Data()
        mockFS.virtualFiles[moduleRoot.path + "/"] = Data()

        let appleSession = MockNetworkSession()
        let searchURL = try #require(URLHelpers.searchURL(query: query))
        appleSession.setResponse(
            for: searchURL,
            data: MockPayloads.emptySearchJSON,
            response: MockPayloads.httpResponse(url: searchURL)
        )
        let dataURL = try #require(URLHelpers.dataURL(for: "/documentation/swiftui/navigationsplitview"))
        appleSession.setResponse(
            for: dataURL,
            data: MockPayloads.docCJSON(
                title: "NavigationSplitView",
                identifier: "doc://com.apple.documentation/documentation/swiftui/navigationsplitview",
                abstract: "A view that presents views in two or three columns."
            ),
            response: MockPayloads.httpResponse(url: dataURL)
        )

        let tool = SearchDocsTool(
            api: AppleJSONAPI(session: appleSession),
            sosumiAPI: SosumiAPI(session: MockNetworkSession()),
            xcodeDocs: XcodeLocalDocs(fileManager: mockFS, searchProvider: MockSearchProvider(), cacheDirectory: cacheDirectory),
            memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5)
        )

        let output = try await tool.runDetailed(query: query)

        #expect(output.results.first?.path == "/documentation/swiftui/navigationsplitview")
        #expect(output.results.first?.source == .apple)
        #expect(output.results.first?.matchScope == .symbol)
        #expect(output.instrumentation.stages.map(\.name).contains("local"))
        #expect(output.instrumentation.stages.map(\.name).contains("apple"))
    }

    @Test("SearchDocsTool keeps module fallback with remote diagnostics when symbol search misses")
    func searchToolKeepsModuleFallbackAfterRemoteMisses() async throws {
        let query = "SwiftUI MissingSymbol"
        let mockFS = MockFileSystem()
        let cacheDirectory = URL(fileURLWithPath: "/tmp/DocumentationCache", isDirectory: true)
        mockFS.virtualFiles[cacheDirectory.path + "/"] = Data()
        let sdkURL = cacheDirectory.appendingPathComponent("26.3")
        let docsRoot = sdkURL.appendingPathComponent("documentation", isDirectory: true)
        let moduleRoot = docsRoot.appendingPathComponent("SwiftUI", isDirectory: true)
        mockFS.virtualFiles[sdkURL.path + "/"] = Data()
        mockFS.virtualFiles[docsRoot.path + "/"] = Data()
        mockFS.virtualFiles[moduleRoot.path + "/"] = Data()

        let appleSession = MockNetworkSession()
        let appleURL = try #require(URLHelpers.searchURL(query: query))
        appleSession.setResponse(
            for: appleURL,
            data: MockPayloads.emptySearchJSON,
            response: MockPayloads.httpResponse(url: appleURL)
        )

        let sosumiSession = MockNetworkSession()
        let sosumiURL = try #require(URLHelpers.sosumiSearchURL(query: query))
        sosumiSession.setResponse(
            for: sosumiURL,
            data: MockPayloads.emptySosumiSearchJSON,
            response: MockPayloads.httpResponse(url: sosumiURL)
        )

        let tool = SearchDocsTool(
            api: AppleJSONAPI(session: appleSession),
            sosumiAPI: SosumiAPI(session: sosumiSession),
            xcodeDocs: XcodeLocalDocs(fileManager: mockFS, searchProvider: MockSearchProvider(), cacheDirectory: cacheDirectory),
            memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5)
        )

        let output = try await tool.runDetailed(query: query)

        #expect(output.results.first?.path == "/documentation/SwiftUI")
        #expect(output.results.first?.matchScope == .module)
        #expect(output.instrumentation.stages.contains { $0.name == "apple" })
        #expect(output.instrumentation.stages.contains { $0.name == "sosumi" })
    }

    @Test("SearchDocsTool prefers local results over remote")
    func searchToolPrefersLocal() async throws {
        let apiSession = MockNetworkSession(stubbedError: MockError.networkTimeout)
        let apple = AppleJSONAPI(session: apiSession)
        let sosumiSession = MockNetworkSession(stubbedError: MockError.networkTimeout)
        let sosumi = SosumiAPI(session: sosumiSession)

        let mockFS = MockFileSystem()
        let mockSearch = MockSearchProvider(
            mockResults: [URL(fileURLWithPath: "/tmp/DocumentationCache/documentation/swiftui/view.json")]
        )
        let xcodeDocs = XcodeLocalDocs(fileManager: mockFS, searchProvider: mockSearch)

        let tool = SearchDocsTool(
            api: apple,
            sosumiAPI: sosumi,
            xcodeDocs: xcodeDocs,
            memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5)
        )

        let result = try await tool.run(query: "View")
        #expect(!result.isEmpty)
        #expect(result.first?.source == .local)
        #expect(apiSession.requestCount == 0)
        #expect(sosumiSession.requestCount == 0)
    }
}
