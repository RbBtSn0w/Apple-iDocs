import Foundation

/// Centralized relevance heuristics, keyword dictionaries, and subgroup boosting rules for search.
public struct SearchRelevanceProfile: Sendable {
    public static let standard = SearchRelevanceProfile()

    public let stopWords: Set<String>
    public let xcodeKeywords: Set<String>
    public let subgroupBoostRules: [SubgroupBoostRule]

    public struct SubgroupBoostRule: Sendable {
        public let urlFragment: String
        public let relevantStems: Set<String>
        public let boost: Double

        public init(urlFragment: String, relevantStems: Set<String>, boost: Double = 50.0) {
            self.urlFragment = urlFragment.lowercased()
            self.relevantStems = Set(relevantStems.map { $0.lowercased() })
            self.boost = boost
        }
    }

    public init(
        stopWords: Set<String> = [
            "how", "do", "does", "can", "i", "we", "you", "a", "an", "the",
            "to", "in", "on", "for", "with", "and", "or", "of", "my", "your",
            "is", "are", "be", "by", "from", "using", "use", "app", "apps"
        ],
        xcodeKeywords: Set<String> = [
            "xcode", "catalog", "string", "local", "localiz", "localizing", "localization",
            "asset", "build", "setting", "agent", "testing", "preview", "scheme",
            "workspace", "project"
        ],
        subgroupBoostRules: [SubgroupBoostRule] = [
            SubgroupBoostRule(
                urlFragment: "localization",
                relevantStems: ["catalog", "string", "local", "localiz", "translat", "languag", "plural", "agent"]
            ),
            SubgroupBoostRule(
                urlFragment: "asset",
                relevantStems: ["asset", "catalog", "image", "icon", "color"]
            ),
            SubgroupBoostRule(
                urlFragment: "coding-intelligence",
                relevantStems: ["agent", "intellig", "ai", "mcp", "complet"]
            )
        ]
    ) {
        self.stopWords = stopWords
        self.xcodeKeywords = xcodeKeywords
        self.subgroupBoostRules = subgroupBoostRules
    }

    /// Calculates additive score boost for a given subgroup URL against token stems.
    public func boost(forSubgroupURL url: String, queryStems: Set<String>) -> Double {
        let urlLower = url.lowercased()
        var totalBoost = 0.0
        for rule in subgroupBoostRules {
            if urlLower.contains(rule.urlFragment) && !queryStems.isDisjoint(with: rule.relevantStems) {
                totalBoost += rule.boost
            }
        }
        return totalBoost
    }
}
