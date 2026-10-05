import Testing
import Foundation
@testable import iDocsKit

@Suite("Search Relevance Profile Tests")
struct SearchRelevanceProfileTests {

    @Test("Standard profile contains common stopwords and Xcode keywords")
    func testStandardProfileContents() {
        let profile = SearchRelevanceProfile.standard

        #expect(profile.stopWords.contains("app"))
        #expect(profile.stopWords.contains("apps"))
        #expect(profile.stopWords.contains("the"))

        #expect(profile.xcodeKeywords.contains("xcode"))
        #expect(profile.xcodeKeywords.contains("catalog"))
        #expect(profile.xcodeKeywords.contains("localization"))
    }

    @Test("Subgroup boost accurately matches relevant stems")
    func testSubgroupBoostCalculation() {
        let profile = SearchRelevanceProfile.standard

        // Localization rule boost
        let locBoost = profile.boost(
            forSubgroupURL: "/documentation/xcode/localization",
            queryStems: ["catalog", "string"]
        )
        #expect(locBoost == 50.0)

        // Asset rule boost
        let assetBoost = profile.boost(
            forSubgroupURL: "/documentation/xcode/asset-management",
            queryStems: ["image", "icon"]
        )
        #expect(assetBoost == 50.0)

        // Coding intelligence / agent rule boost
        let agentBoost = profile.boost(
            forSubgroupURL: "/documentation/xcode/coding-intelligence",
            queryStems: ["agent"]
        )
        #expect(agentBoost == 50.0)

        // Non-matching query yields 0 boost
        let zeroBoost = profile.boost(
            forSubgroupURL: "/documentation/xcode/build-system",
            queryStems: ["unrelated"]
        )
        #expect(zeroBoost == 0.0)
    }

    @Test("SearchQueryIntent consumes custom SearchRelevanceProfile")
    func testCustomProfileInjection() {
        let customProfile = SearchRelevanceProfile(
            stopWords: ["customstop"],
            xcodeKeywords: ["customkw"],
            subgroupBoostRules: [
                SearchRelevanceProfile.SubgroupBoostRule(
                    urlFragment: "custom",
                    relevantStems: ["boostme"],
                    boost: 100.0
                )
            ]
        )

        let intent = SearchQueryIntent("customstop test query", profile: customProfile)
        #expect(!intent.tokenStems.contains("customstop"))
        #expect(intent.tokenStems.contains("test"))

        let boost = customProfile.boost(forSubgroupURL: "https://example.com/custom", queryStems: ["boostme"])
        #expect(boost == 100.0)
    }
}
