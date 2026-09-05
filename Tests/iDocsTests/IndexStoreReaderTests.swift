import Testing
import Foundation
@testable import iDocsKit

@Suite("IndexStoreReader Tests")
struct IndexStoreReaderTests {
    let reader = IndexStoreReader()

    // MARK: - Token Existence

    @Test("containsToken matches token bounded by null bytes or non-alphanumerics")
    func containsTokenBounded() {
        var data = Data([0x00])
        data.append(contentsOf: "SwiftUI".utf8)
        data.append(0x00)
        data.append(contentsOf: "OtherToken".utf8)
        data.append(0x20) // space
        data.append(contentsOf: "AppKit".utf8)

        #expect(reader.containsToken("SwiftUI", in: data) == true)
        #expect(reader.containsToken("OtherToken", in: data) == true)
        #expect(reader.containsToken("AppKit", in: data) == true)
        #expect(reader.containsToken("Missing", in: data) == false)
    }

    @Test("containsToken rejects token when embedded inside longer alphanumeric word")
    func containsTokenRejectsEmbeddedSubstrings() {
        let data = Data("SwiftUIComponent".utf8)
        #expect(reader.containsToken("SwiftUI", in: data) == false)
    }

    @Test("containsToken handles empty query and empty data")
    func containsTokenEmptyCases() {
        #expect(reader.containsToken("", in: Data("SwiftUI".utf8)) == false)
        #expect(reader.containsToken("SwiftUI", in: Data()) == false)
    }

    // MARK: - Byte Classification

    @Test("isPathByte validates valid URL path characters")
    func isPathByteValidCharacters() {
        let validPathString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._/"
        for byte in validPathString.utf8 {
            #expect(reader.isPathByte(byte) == true)
        }

        let invalidCharacters: [UInt8] = [0x00, 0x20, UInt8(ascii: "#"), UInt8(ascii: "?"), UInt8(ascii: "%")]
        for byte in invalidCharacters {
            #expect(reader.isPathByte(byte) == false)
        }
    }

    @Test("isModuleByte validates alphanumerics")
    func isModuleByteValidates() {
        #expect(reader.isModuleByte(UInt8(ascii: "A")) == true)
        #expect(reader.isModuleByte(UInt8(ascii: "z")) == true)
        #expect(reader.isModuleByte(UInt8(ascii: "0")) == true)
        #expect(reader.isModuleByte(UInt8(ascii: "/")) == false)
        #expect(reader.isModuleByte(UInt8(ascii: "-")) == false)
    }

    // MARK: - Query Tokenization

    @Test("tokenize splits query into clean lowercase tokens")
    func tokenizeSplitsCorrectly() {
        let tokens = reader.tokenize(query: "SwiftUI: NavigationSplitView (macOS 14+)")
        #expect(tokens == ["swiftui", "navigationsplitview", "macos", "14"])
    }

    // MARK: - Path Scoring

    @Test("scoreForPath gives higher score to suffix match than prefix match")
    func scoreForPathSuffixPreference() {
        let tokens = ["navigationsplitview"]
        let exactMember = "/documentation/swiftui/navigationsplitview"
        let parentModule = "/documentation/navigationsplitview/overview"

        let exactScore = reader.scoreForPath(exactMember, tokens: tokens)
        let parentScore = reader.scoreForPath(parentModule, tokens: tokens)

        #expect(exactScore > parentScore)
    }

    @Test("scoreForPath penalizes longer paths when token matches are equal")
    func scoreForPathLengthPenalty() {
        let tokens = ["view"]
        let shortPath = "/documentation/swiftui/view"
        let longPath = "/documentation/swiftui/verylongextendedmodulecontainer/view"

        let shortScore = reader.scoreForPath(shortPath, tokens: tokens)
        let longScore = reader.scoreForPath(longPath, tokens: tokens)

        #expect(shortScore > longScore)
    }

    @Test("scoreForPath returns 0 for completely unrelated paths")
    func scoreForPathNoMatch() {
        let tokens = ["widgetkit"]
        let path = "/documentation/swiftui/view"
        #expect(reader.scoreForPath(path, tokens: tokens) == 0)
    }

    // MARK: - Binary Index Store Path Extraction & Ranking

    @Test("rankDocumentationPaths extracts and sorts valid paths from binary fixture")
    func rankDocumentationPathsFixture() {
        // Construct a synthetic binary index store fixture
        var fixtureData = Data([0xDE, 0xAD, 0xBE, 0xEF]) // Binary header bytes
        fixtureData.append(0x00)
        fixtureData.append(contentsOf: "/documentation/swiftui".utf8)
        fixtureData.append(0x00)
        fixtureData.append(contentsOf: "/documentation/swiftui/navigationsplitview".utf8)
        fixtureData.append(0x00)
        fixtureData.append(contentsOf: "/documentation/appkit/nssplitviewcontroller".utf8)
        fixtureData.append(0x00)
        fixtureData.append(contentsOf: "/invalid/not-doc-path".utf8)
        fixtureData.append(0x00)
        fixtureData.append(0xFF)

        let matches = reader.search(query: "SwiftUI NavigationSplitView", in: fixtureData)

        #expect(matches.count == 2)
        // navigationsplitview matches both 'swiftui' and 'navigationsplitview', should be ranked first
        #expect(matches.first?.path == "/documentation/swiftui/navigationsplitview")
        #expect(matches.last?.path == "/documentation/swiftui")
    }

    @Test("rankDocumentationPaths enforces maxPathLength bound")
    func rankDocumentationPathsEnforcesMaxLength() {
        var fixtureData = Data([0x00])
        fixtureData.append(contentsOf: "/documentation/".utf8)
        fixtureData.append(Data(repeating: UInt8(ascii: "a"), count: 300))
        fixtureData.append(0x00)

        let customReader = IndexStoreReader(maxPathLength: 50)
        let matches = customReader.rankDocumentationPaths(in: fixtureData, tokens: ["a"])

        #expect(matches.count == 1)
        #expect(matches.first?.path.count ?? 0 <= 50)
    }

    @Test("title derives clean symbol name from path")
    func titleDerivation() {
        #expect(reader.title(from: "/documentation/swiftui/navigation-split-view") == "navigation split view")
        #expect(reader.title(from: "/documentation/swiftui") == "swiftui")
    }

    // MARK: - Regression: 2026-05-16 Search Module Hint Short-Circuit

    @Test("Composite symbol query prefers symbol match over module match in binary index")
    func compositeQueryPrefersSymbolMatchOverModuleMatch() {
        var fixtureData = Data()
        fixtureData.append(contentsOf: "/documentation/swiftui\0".utf8)
        fixtureData.append(contentsOf: "/documentation/swiftui/navigationsplitview\0".utf8)

        let results = reader.search(query: "SwiftUI NavigationSplitView", in: fixtureData)

        #expect(results.count == 2)
        #expect(results[0].path == "/documentation/swiftui/navigationsplitview")
        #expect(results[1].path == "/documentation/swiftui")
        #expect(results[0].score > results[1].score)
    }
}
