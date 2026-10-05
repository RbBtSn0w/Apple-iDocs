import Testing
import Foundation
@testable import iDocsKit

@Suite("Apple Remote Search Crawler Tests")
struct AppleRemoteSearchCrawlerTests {

    @Test("parseIndexedResults scores and sorts matching references")
    func parseIndexedResultsScoring() {
        let client = AppleDocumentationHTTPClient(retryDelayNanoseconds: 0)
        let crawler = AppleRemoteSearchCrawler(httpClient: client)

        let refExact = DocumentationReference(
            title: "View",
            role: "symbol",
            url: "/documentation/swiftui/view",
            abstract: [InlineText(text: "A type representing UI.")]
        )
        let refPrefix = DocumentationReference(
            title: "ViewThatFits",
            role: "symbol",
            url: "/documentation/swiftui/viewthatfits",
            abstract: [InlineText(text: "A view adapting size.")]
        )
        let refUnrelated = DocumentationReference(
            title: "Color",
            role: "symbol",
            url: "/documentation/swiftui/color",
            abstract: [InlineText(text: "A color representation.")]
        )

        let indexResponse = DocumentationIndexResponse(
            references: [
                "1": refExact,
                "2": refPrefix,
                "3": refUnrelated
            ]
        )

        let results = crawler.parseIndexedResults(response: indexResponse, normalizedQuery: "view")
        #expect(results.count == 2)
        #expect(results.first?.title == "View")
        #expect(results.last?.title == "ViewThatFits")
    }

    @Test("documentKind maps documentation roles and kinds")
    func documentKindMapping() {
        let client = AppleDocumentationHTTPClient(retryDelayNanoseconds: 0)
        let crawler = AppleRemoteSearchCrawler(httpClient: client)

        #expect(crawler.documentKind(kind: "class", role: nil, type: nil) == .class)
        #expect(crawler.documentKind(kind: nil, role: "symbol", type: "struct") == .structure)
        #expect(crawler.documentKind(kind: "protocol", role: nil, type: nil) == .protocol)
        #expect(crawler.documentKind(kind: "framework", role: nil, type: nil) == .framework)
        #expect(crawler.documentKind(kind: "article", role: nil, type: nil) == .article)
        #expect(crawler.documentKind(kind: nil, role: "samplecode", type: nil) == .sampleCode)
        #expect(crawler.documentKind(kind: "unknown", role: nil, type: nil) == .overview)
    }

    @Test("searchTechnologyGraph traverses and returns candidates")
    func technologyGraphTraversal() async throws {
        let session = MockNetworkSession()
        let query = "SplitNavigationContainer"
        let tech = Technology(name: "SwiftUI", url: "/documentation/swiftui", kind: "framework")

        let moduleURL = try #require(URLHelpers.dataURL(for: "/documentation/swiftui"))
        session.setResponse(
            for: moduleURL,
            data: MockPayloads.technologyGraphJSON(
                references: [
                    (
                        title: "SplitNavigationContainer",
                        path: "/documentation/swiftui/splitnavigationcontainer",
                        abstract: "Split column container.",
                        role: "symbol"
                    )
                ]
            ),
            response: MockPayloads.httpResponse(url: moduleURL)
        )

        let client = AppleDocumentationHTTPClient(session: session, retryDelayNanoseconds: 0)
        let crawler = AppleRemoteSearchCrawler(httpClient: client)

        let results = try await crawler.searchTechnologyGraph(query: query, technologies: [tech])
        #expect(!results.isEmpty)
        #expect(results.first?.title == "SplitNavigationContainer")
        #expect(results.first?.path == "/documentation/swiftui/splitnavigationcontainer")
    }

    @Test("searchTechnologyGraph aborts upon cancellation")
    func searchTechnologyGraphRespectsCancellation() async throws {
        let session = MockNetworkSession(stubbedError: URLError(.cancelled))
        let client = AppleDocumentationHTTPClient(session: session, retryDelayNanoseconds: 0)
        let crawler = AppleRemoteSearchCrawler(httpClient: client)
        let tech = Technology(name: "SwiftUI", url: "/documentation/swiftui", kind: "framework")

        let task = Task {
            try await crawler.searchTechnologyGraph(query: "SwiftUI View", technologies: [tech])
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}
