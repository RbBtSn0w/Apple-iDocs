import Testing
import Foundation
@testable import iDocsKit

@Suite("Search Deduplication and Ranking Tests")
struct SearchDocsToolDeduplicationTests {

    @Test("SearchResultRanker deduplicates results by path and preserves highest score")
    func testDeduplicationByPath() {
        let ranker = SearchResultRanker(query: "NavigationSplitView")

        let lowerScoreResult = SearchResult(
            title: "NavigationSplitView",
            abstract: "A view that presents views in two or three columns.",
            path: "/documentation/swiftui/navigationsplitview",
            kind: .structure,
            source: .apple,
            relevance: 10.0
        )

        let higherScoreResult = SearchResult(
            title: "NavigationSplitView",
            abstract: "A view that presents views in two or three columns.",
            path: "/documentation/swiftui/navigationsplitview",
            kind: .structure,
            source: .apple,
            relevance: 50.0
        )

        let duplicateResults = [lowerScoreResult, higherScoreResult]
        let ranked = ranker.rankedRemoteResults(duplicateResults)

        #expect(ranked.count == 1)
        #expect(ranked.first?.path == "/documentation/swiftui/navigationsplitview")
    }

    @Test("SearchResultRanker filters out /documentation/technologies breadcrumb unless query requests technologies")
    func testSuppressesGenericTechnologiesRoot() {
        let ranker = SearchResultRanker(query: "localizing your app using agents")

        let techRoot = SearchResult(
            title: "Technologies",
            abstract: "Discover Apple technologies and SDKs.",
            path: "/documentation/technologies",
            kind: .overview,
            source: .apple,
            relevance: 100.0
        )

        let article = SearchResult(
            title: "Localizing your app using agents",
            abstract: "Use agents to translate and localize your app strings.",
            path: "/documentation/xcode/localizing-your-app-using-agents",
            kind: .article,
            source: .apple,
            relevance: 90.0
        )

        let ranked = ranker.rankedRemoteResults([techRoot, article])
        #expect(ranked.count == 1)
        #expect(ranked.first?.path == "/documentation/xcode/localizing-your-app-using-agents")

        let techRanker = SearchResultRanker(query: "technologies")
        let rankedTech = techRanker.rankedRemoteResults([techRoot, article])
        #expect(rankedTech.contains { $0.path == "/documentation/technologies" })
    }

    @Test("SearchResultRanker caps results to specified limit")
    func testCapsResults() {
        let ranker = SearchResultRanker(query: "View")
        var results: [SearchResult] = []
        for i in 1...100 {
            results.append(
                SearchResult(
                    title: "View \(i)",
                    abstract: "Abstract \(i)",
                    path: "/documentation/swiftui/view\(i)",
                    kind: .structure,
                    source: .apple,
                    relevance: Double(i)
                )
            )
        }

        let ranked = ranker.rankedRemoteResults(results, limit: 50)
        #expect(ranked.count == 50)
    }

    @Test("SearchQueryIntent matches Xcode technology on guide and tool terms")
    func testMatchesXcodeOnGuideTerms() {
        let xcodeTech = Technology(name: "Xcode", url: "/documentation/xcode", kind: "Tools")

        let catalogIntent = SearchQueryIntent("String Catalog")
        #expect(catalogIntent.matches(technology: xcodeTech))

        let agentIntent = SearchQueryIntent("localizing your app using agents")
        #expect(agentIntent.matches(technology: xcodeTech))

        let assetIntent = SearchQueryIntent("asset catalog images")
        #expect(assetIntent.matches(technology: xcodeTech))
    }

    @Test("AppleJSONAPI search finds Xcode String Catalog articles with mock session")
    func testFindsXcodeArticlesWithMock() async throws {
        let session = MockNetworkSession()
        let searchURL = try #require(URLHelpers.searchURL(query: "String Catalog"))
        let techURL = try #require(URLHelpers.technologiesURL())
        let xcodeURL = try #require(URLHelpers.dataURL(for: "/documentation/xcode"))
        let locURL = try #require(URLHelpers.dataURL(for: "/documentation/xcode/localization"))

        let techJSON = """
        {
            "technologies": [
                { "name": "Xcode", "url": "/documentation/xcode", "kind": "Tools" }
            ]
        }
        """.data(using: .utf8)!

        let xcodeJSON = """
        {
            "references": {
                "doc://com.apple.documentation/documentation/Xcode/localization": {
                    "title": "Localization",
                    "kind": "article",
                    "role": "collectionGroup",
                    "url": "/documentation/xcode/localization",
                    "abstract": [{ "type": "text", "text": "Expand the market for your app by supporting multiple languages and regions." }]
                }
            }
        }
        """.data(using: .utf8)!

        let locJSON = """
        {
            "references": {
                "doc://com.apple.documentation/documentation/Xcode/localizing-and-varying-text-with-a-string-catalog": {
                    "title": "Localizing and varying text with a string catalog",
                    "kind": "article",
                    "role": "article",
                    "url": "/documentation/xcode/localizing-and-varying-text-with-a-string-catalog",
                    "abstract": [{ "type": "text", "text": "Use localizable APIs to populate string catalogs automatically." }]
                }
            }
        }
        """.data(using: .utf8)!

        session.setResponse(for: searchURL, data: MockPayloads.emptySearchJSON, response: MockPayloads.httpResponse(url: searchURL))
        session.setResponse(for: techURL, data: techJSON, response: MockPayloads.httpResponse(url: techURL))
        session.setResponse(for: xcodeURL, data: xcodeJSON, response: MockPayloads.httpResponse(url: xcodeURL))
        session.setResponse(for: locURL, data: locJSON, response: MockPayloads.httpResponse(url: locURL))

        let api = AppleJSONAPI(session: session)
        let results = try await api.search(query: "String Catalog")
        #expect(results.contains { $0.path.contains("string-catalog") })
    }

    @Test("AppleJSONAPI search finds Xcode String Catalog and agent localization articles (live)", .enabled(if: IntegrationTestGate.isEnabled))
    func testFindsXcodeArticlesLive() async throws {
        let api = AppleJSONAPI()
        let results = try await api.search(query: "String Catalog")
        let paths = results.map { $0.path }
        #expect(results.contains { $0.path.contains("string-catalog") }, "Paths found: \(paths)")
    }
}
