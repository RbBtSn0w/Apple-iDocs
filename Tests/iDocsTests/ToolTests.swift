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

    @Test("AppleJSONAPI searches a technology graph when the search index misses")
    func appleSearchesTechnologyGraphWhenIndexMisses() async throws {
        let session = MockNetworkSession()
        let query = "SwiftUI SplitNavigationContainer"
        let searchURL = try #require(URLHelpers.searchURL(query: query))
        session.setResponse(
            for: searchURL,
            data: MockPayloads.emptySearchJSON,
            response: MockPayloads.httpResponse(url: searchURL)
        )

        if let technologiesURL = URLHelpers.technologiesURL() {
            session.setResponse(
                for: technologiesURL,
                data: MockPayloads.technologiesModernJSON,
                response: MockPayloads.httpResponse(url: technologiesURL)
            )
        }

        let moduleURL = try #require(URLHelpers.dataURL(for: "/documentation/swiftui"))
        session.setResponse(
            for: moduleURL,
            data: MockPayloads.technologyGraphJSON(
                references: [
                    (
                        title: "SplitNavigationContainerStyle",
                        path: "/documentation/swiftui/view/splitnavigationcontainerstyle(_:)",
                        abstract: "Sets the style for split navigation containers.",
                        role: "symbol"
                    ),
                    (
                        title: "SplitNavigationContainer",
                        path: "/documentation/swiftui/splitnavigationcontainer",
                        abstract: "A view that presents navigation content in split columns.",
                        role: "symbol"
                    )
                ]
            ),
            response: MockPayloads.httpResponse(url: moduleURL)
        )

        let api = AppleJSONAPI(session: session)
        let results = try await api.search(query: query)

        #expect(results.first?.title == "SplitNavigationContainer")
        #expect(results.first?.path == "/documentation/swiftui/splitnavigationcontainer")
        #expect(results.first?.source == .apple)
    }

    @Test("AppleJSONAPI searches technology graph for exact symbol without framework")
    func appleSearchesTechnologyGraphForBareExactSymbol() async throws {
        let session = MockNetworkSession()
        let query = "NavigationSplitView"
        let searchURL = try #require(URLHelpers.searchURL(query: query))
        session.setResponse(
            for: searchURL,
            data: MockPayloads.emptySearchJSON,
            response: MockPayloads.httpResponse(url: searchURL)
        )

        if let technologiesURL = URLHelpers.technologiesURL() {
            session.setResponse(
                for: technologiesURL,
                data: MockPayloads.technologiesModernJSON,
                response: MockPayloads.httpResponse(url: technologiesURL)
            )
        }

        let moduleURL = try #require(URLHelpers.dataURL(for: "/documentation/swiftui"))
        session.setResponse(
            for: moduleURL,
            data: MockPayloads.technologyGraphJSON(
                references: [
                    (
                        title: "NavigationSplitView",
                        path: "/documentation/swiftui/navigationsplitview",
                        abstract: "A view that presents columns.",
                        role: "symbol"
                    )
                ]
            ),
            response: MockPayloads.httpResponse(url: moduleURL)
        )

        let api = AppleJSONAPI(session: session)
        let results = try await api.search(query: query)

        #expect(results.first?.path == "/documentation/swiftui/navigationsplitview")
        #expect(results.first?.title == "NavigationSplitView")
    }

    @Test("AppleJSONAPI preserves technology graph transport failures")
    func appleTechnologyGraphPreservesTransportFailures() async throws {
        let session = MockNetworkSession()
        let query = "SwiftUI SplitNavigationContainer"
        let searchURL = try #require(URLHelpers.searchURL(query: query))
        session.setResponse(
            for: searchURL,
            data: MockPayloads.emptySearchJSON,
            response: MockPayloads.httpResponse(url: searchURL)
        )
        if let technologiesURL = URLHelpers.technologiesURL() {
            session.setResponse(
                for: technologiesURL,
                data: MockPayloads.technologiesModernJSON,
                response: MockPayloads.httpResponse(url: technologiesURL)
            )
        }
        let moduleURL = try #require(URLHelpers.dataURL(for: "/documentation/swiftui"))
        session.setError(for: moduleURL, error: URLError(.notConnectedToInternet))

        let api = AppleJSONAPI(session: session)

        do {
            _ = try await api.search(query: query)
            Issue.record("Expected technology graph transport failure to be propagated.")
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
        let query = "View"
        let appleSession = MockNetworkSession()
        let appleURL = try #require(URLHelpers.searchURL(query: query))
        appleSession.setResponse(
            for: appleURL,
            data: MockPayloads.emptySearchJSON,
            response: MockPayloads.httpResponse(url: appleURL)
        )

        let sosumi = makeMockSosumiAPI(queries: [query])
        let tool = SearchDocsTool(
            api: AppleJSONAPI(session: appleSession),
            sosumiAPI: sosumi,
            xcodeDocs: XcodeLocalDocs(fileManager: MockFileSystem(), searchProvider: MockSearchProvider(), cacheDirectory: nil, indexStoreQueryCache: IndexStoreQueryCache()),
            memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5)
        )

        let result = try await tool.run(query: query)
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
        if let technologiesURL = URLHelpers.technologiesURL() {
            appleSession.setResponse(
                for: technologiesURL,
                data: MockPayloads.technologiesModernJSON,
                response: MockPayloads.httpResponse(url: technologiesURL)
            )
        }

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
            xcodeDocs: XcodeLocalDocs(fileManager: MockFileSystem(), searchProvider: MockSearchProvider(), cacheDirectory: nil, indexStoreQueryCache: IndexStoreQueryCache()),
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
            xcodeDocs: XcodeLocalDocs(fileManager: MockFileSystem(), searchProvider: MockSearchProvider(), cacheDirectory: nil, indexStoreQueryCache: IndexStoreQueryCache()),
            memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5)
        )

        let output = try await tool.runDetailed(query: query)

        #expect(!output.results.isEmpty)
        #expect(output.results.allSatisfy { $0.queryAttempt == derivedQuery })
        #expect(output.instrumentation.stages.contains { $0.queryAttempt == query })
        #expect(output.instrumentation.stages.contains { $0.queryAttempt == derivedQuery })
    }

    @Test("SearchDocsTool promotes canonical documentation over broad remote hits")
    func searchToolPromotesCanonicalDocumentationOverBroadRemoteHits() async throws {
        let query = "UIViewController"

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
            data: """
            {
                "query": "UIViewController",
                "results": [
                    {
                        "title": "Advanced View Controller Transitions",
                        "url": "https://developer.apple.com/videos/play/wwdc2015/504",
                        "description": "Video session about view controller transitions.",
                        "type": "other"
                    },
                    {
                        "title": "UIViewController",
                        "url": "https://developer.apple.com/documentation/uikit/uiviewcontroller",
                        "description": "An object that manages a view hierarchy for your UIKit app.",
                        "type": "documentation"
                    }
                ]
            }
            """.data(using: .utf8)!,
            response: MockPayloads.httpResponse(url: sosumiURL)
        )

        let tool = SearchDocsTool(
            api: AppleJSONAPI(session: appleSession),
            sosumiAPI: SosumiAPI(session: sosumiSession),
            xcodeDocs: XcodeLocalDocs(fileManager: MockFileSystem(), searchProvider: MockSearchProvider(), cacheDirectory: nil, indexStoreQueryCache: IndexStoreQueryCache()),
            memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5)
        )

        let output = try await tool.runDetailed(query: query)

        #expect(output.results.first?.path == "/documentation/uikit/uiviewcontroller")
        #expect(output.results.first?.sourceKind == .documentation)
        #expect(output.results.first?.fetchSupported == true)
    }

    @Test("SearchDocsTool promotes type page over member style for natural language queries")
    func searchToolPromotesTypePageOverMemberStyleForNaturalLanguageQueries() async throws {
        let query = "How do I create a split navigation interface in SwiftUI?"

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
            data: """
            {
                "query": "How do I create a split navigation interface in SwiftUI?",
                "results": [
                    {
                        "title": "NavigationSplitViewVisibility",
                        "url": "https://developer.apple.com/documentation/swiftui/navigationsplitviewvisibility",
                        "description": "The visibility of the leading columns in a navigation split view.",
                        "type": "documentation"
                    },
                    {
                        "title": "navigationSplitViewStyle(_:)",
                        "url": "https://developer.apple.com/documentation/swiftui/view/navigationsplitviewstyle(_:)",
                        "description": "Sets the style for navigation split views within this view.",
                        "type": "documentation"
                    },
                    {
                        "title": "NavigationSplitView",
                        "url": "https://developer.apple.com/documentation/swiftui/navigationsplitview",
                        "description": "A view that presents views in two or three columns.",
                        "type": "documentation"
                    }
                ]
            }
            """.data(using: .utf8)!,
            response: MockPayloads.httpResponse(url: sosumiURL)
        )

        let tool = SearchDocsTool(
            api: AppleJSONAPI(session: appleSession),
            sosumiAPI: SosumiAPI(session: sosumiSession),
            xcodeDocs: XcodeLocalDocs(fileManager: MockFileSystem(), searchProvider: MockSearchProvider(), cacheDirectory: nil, indexStoreQueryCache: IndexStoreQueryCache()),
            memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5)
        )

        let output = try await tool.runDetailed(query: query)

        #expect(output.results.first?.path == "/documentation/swiftui/navigationsplitview")
        #expect(output.results.first?.matchScope == .symbol)
    }

    @Test("SearchDocsTool promotes App Store Connect help title intent")
    func searchToolPromotesAppStoreConnectHelpTitleIntent() async throws {
        let query = "App Store Connect upload builds"

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
            data: """
            {
                "query": "App Store Connect upload builds",
                "results": [
                    {
                        "title": "App build statuses - App uploads - Reference - App Store Connect - Help - Apple Developer",
                        "url": "https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-build-statuses",
                        "description": "Reference build status values.",
                        "type": "general"
                    },
                    {
                        "title": "Upload builds - Manage builds - App Store Connect - Help - Apple Developer",
                        "url": "https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds",
                        "description": "Upload builds to App Store Connect.",
                        "type": "general"
                    }
                ]
            }
            """.data(using: .utf8)!,
            response: MockPayloads.httpResponse(url: sosumiURL)
        )

        let tool = SearchDocsTool(
            api: AppleJSONAPI(session: appleSession),
            sosumiAPI: SosumiAPI(session: sosumiSession),
            xcodeDocs: XcodeLocalDocs(fileManager: MockFileSystem(), searchProvider: MockSearchProvider(), cacheDirectory: nil, indexStoreQueryCache: IndexStoreQueryCache()),
            memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5)
        )

        let output = try await tool.runDetailed(query: query)

        #expect(output.results.first?.path == "/help/app-store-connect/manage-builds/upload-builds")
        #expect(output.results.first?.sourceKind == .help)
    }

    @Test("SearchDocsTool promotes UIKit present method over presentation properties")
    func searchToolPromotesUIKitPresentMethodOverPresentationProperties() async throws {
        let query = "UIViewController presentViewController"

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
            data: """
            {
                "query": "UIViewController presentViewController",
                "results": [
                    {
                        "title": "presentedViewController",
                        "url": "https://developer.apple.com/documentation/uikit/uiviewcontroller/presentedviewcontroller",
                        "description": "The view controller that is presented.",
                        "type": "documentation"
                    },
                    {
                        "title": "present(_:animated:completion:)",
                        "url": "https://developer.apple.com/documentation/uikit/uiviewcontroller/present(_:animated:completion:)",
                        "description": "Presents a view controller modally.",
                        "type": "documentation"
                    }
                ]
            }
            """.data(using: .utf8)!,
            response: MockPayloads.httpResponse(url: sosumiURL)
        )

        let tool = SearchDocsTool(
            api: AppleJSONAPI(session: appleSession),
            sosumiAPI: SosumiAPI(session: sosumiSession),
            xcodeDocs: XcodeLocalDocs(fileManager: MockFileSystem(), searchProvider: MockSearchProvider(), cacheDirectory: nil, indexStoreQueryCache: IndexStoreQueryCache()),
            memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5)
        )

        let output = try await tool.runDetailed(query: query)

        #expect(output.results.first?.path == "/documentation/uikit/uiviewcontroller/present(_:animated:completion:)")
        #expect(output.results.first?.matchScope == .member)
    }

    @Test("SearchDocsTool promotes Foundation exact symbol over cross-framework lowercase matches")
    func searchToolPromotesFoundationExactSymbolOverCrossFrameworkLowercaseMatches() async throws {
        let query = "URLSession"

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
            data: """
            {
                "query": "URLSession",
                "results": [
                    {
                        "title": "urlSession",
                        "url": "https://developer.apple.com/documentation/swiftui/backgroundtask/urlsession",
                        "description": "A task that responds to background URL sessions.",
                        "type": "documentation"
                    },
                    {
                        "title": "URLSession",
                        "url": "https://developer.apple.com/documentation/foundation/urlsession",
                        "description": "An object that coordinates network data transfer tasks.",
                        "type": "documentation"
                    }
                ]
            }
            """.data(using: .utf8)!,
            response: MockPayloads.httpResponse(url: sosumiURL)
        )

        let tool = SearchDocsTool(
            api: AppleJSONAPI(session: appleSession),
            sosumiAPI: SosumiAPI(session: sosumiSession),
            xcodeDocs: XcodeLocalDocs(fileManager: MockFileSystem(), searchProvider: MockSearchProvider(), cacheDirectory: nil, indexStoreQueryCache: IndexStoreQueryCache()),
            memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5)
        )

        let output = try await tool.runDetailed(query: query)

        #expect(output.results.first?.path == "/documentation/foundation/urlsession")
        #expect(output.results.first?.sourceKind == .documentation)
    }

    @Test("SearchDocsTool returns empty for low confidence framework-qualified symbol misses")
    func searchToolReturnsEmptyForLowConfidenceFrameworkQualifiedSymbolMisses() async throws {
        let query = "SwiftUI DefinitelyNotARealSymbol999"

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
            data: """
            {
                "query": "SwiftUI DefinitelyNotARealSymbol999",
                "results": [
                    {
                        "title": "SwiftUI updates",
                        "url": "https://developer.apple.com/documentation/updates/swiftui",
                        "description": "Learn about important changes to SwiftUI.",
                        "type": "documentation"
                    },
                    {
                        "title": "List",
                        "url": "https://developer.apple.com/documentation/swiftui/list",
                        "description": "A container that presents rows of data.",
                        "type": "documentation"
                    }
                ]
            }
            """.data(using: .utf8)!,
            response: MockPayloads.httpResponse(url: sosumiURL)
        )

        let tool = SearchDocsTool(
            api: AppleJSONAPI(session: appleSession),
            sosumiAPI: SosumiAPI(session: sosumiSession),
            xcodeDocs: XcodeLocalDocs(fileManager: MockFileSystem(), searchProvider: MockSearchProvider(), cacheDirectory: nil, indexStoreQueryCache: IndexStoreQueryCache()),
            memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5)
        )

        let output = try await tool.runDetailed(query: query)

        #expect(output.results.isEmpty)
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
        if let technologiesURL = URLHelpers.technologiesURL() {
            appleSession.setResponse(
                for: technologiesURL,
                data: MockPayloads.technologiesModernJSON,
                response: MockPayloads.httpResponse(url: technologiesURL)
            )
        }
        let moduleURL = try #require(URLHelpers.dataURL(for: "/documentation/swiftui"))
        appleSession.setResponse(
            for: moduleURL,
            data: MockPayloads.technologyGraphJSON(
                references: [
                    (
                        title: "NavigationSplitView",
                        path: "/documentation/swiftui/navigationsplitview",
                        abstract: "A view that presents views in two or three columns.",
                        role: "symbol"
                    )
                ]
            ),
            response: MockPayloads.httpResponse(url: moduleURL)
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

    @Test("SearchDocsTool does not cache empty remote misses")
    func searchToolDoesNotCacheEmptyRemoteMisses() async throws {
        let query = "DefinitelyMissingSearchQualitySymbol"
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
            xcodeDocs: XcodeLocalDocs(fileManager: MockFileSystem(), searchProvider: MockSearchProvider(), cacheDirectory: nil, indexStoreQueryCache: IndexStoreQueryCache()),
            memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5)
        )

        let first = try await tool.runDetailed(query: query)
        let second = try await tool.runDetailed(query: query)

        #expect(first.results.isEmpty)
        #expect(second.results.isEmpty)
        #expect(appleSession.requestedURLs.filter { $0 == appleURL }.count == 2)
        #expect(sosumiSession.requestedURLs.filter { $0 == sosumiURL }.count == 2)
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

    @Test("SearchDocsTool skips sosumi fallback for opaque long misses")
    func searchToolSkipsSosumiForOpaqueLongMisses() async throws {
        let query = "qwertyzzdocnotfound"
        let appleSession = MockNetworkSession()
        let appleURL = try #require(URLHelpers.searchURL(query: query))
        appleSession.setResponse(
            for: appleURL,
            data: MockPayloads.emptySearchJSON,
            response: MockPayloads.httpResponse(url: appleURL)
        )
        let techURL = try #require(URLHelpers.technologiesURL())
        appleSession.setResponse(
            for: techURL,
            data: MockPayloads.technologiesJSON,
            response: MockPayloads.httpResponse(url: techURL)
        )

        let sosumiSession = MockNetworkSession()
        let sosumiURL = try #require(URLHelpers.sosumiSearchURL(query: query))
        sosumiSession.setResponse(
            for: sosumiURL,
            data: MockPayloads.sosumiSearchJSON,
            response: MockPayloads.httpResponse(url: sosumiURL)
        )

        let tool = SearchDocsTool(
            api: AppleJSONAPI(session: appleSession),
            sosumiAPI: SosumiAPI(session: sosumiSession),
            xcodeDocs: XcodeLocalDocs(fileManager: MockFileSystem(), searchProvider: MockSearchProvider(), cacheDirectory: nil, indexStoreQueryCache: IndexStoreQueryCache()),
            memoryCache: MemoryCache<String, [SearchResult]>(capacity: 5),
            remoteSearchTimeoutSeconds: 0
        )

        let output = try await tool.runDetailed(query: query)

        #expect(output.results.isEmpty)
        #expect(appleSession.requestedURLs.filter { $0 == appleURL }.count == 1)
        #expect(sosumiSession.requestCount == 0)
        #expect(output.instrumentation.stages.last?.name == "sosumi")
        #expect(output.instrumentation.stages.last?.status == .skipped)
        #expect(output.instrumentation.stages.last?.reason == "opaque_miss_query")
    }
}
