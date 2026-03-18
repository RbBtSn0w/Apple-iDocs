import Testing
import Foundation
@testable import iDocsKit

@Suite("URLHelpers Tests")
struct URLHelpersTests {
    @Test("normalizePath adds leading slash and trims whitespace")
    func normalizePath() {
        let normalized = URLHelpers.normalizePath("  documentation/swiftui/view ")
        #expect(normalized == "/documentation/swiftui/view")
    }

    @Test("dataURL builds tutorials data JSON URL")
    func dataURL() {
        let url = URLHelpers.dataURL(for: "/documentation/swiftui/view")
        #expect(url?.absoluteString == "https://developer.apple.com/tutorials/data/documentation/swiftui/view.json")
    }

    @Test("webURL builds developer URL")
    func webURL() {
        let url = URLHelpers.webURL(for: "documentation/swiftui/view")
        #expect(url?.absoluteString == "https://developer.apple.com/documentation/swiftui/view")
    }

    @Test("sosumi search URL builds correctly")
    func sosumiSearchURL() {
        let url = URLHelpers.sosumiSearchURL(query: "swiftui")
        #expect(url?.absoluteString == "https://sosumi.ai/search?q=swiftui")
    }

    @Test("sosumi fetch URL builds correctly")
    func sosumiFetchURL() {
        let url = URLHelpers.sosumiFetchURL(for: "/documentation/swiftui/view")
        #expect(url?.absoluteString == "https://sosumi.ai/documentation/swiftui/view")
    }
}
