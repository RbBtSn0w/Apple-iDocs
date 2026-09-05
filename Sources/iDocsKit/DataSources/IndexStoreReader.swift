import Foundation

/// Represents a scored documentation path match found in an index store.
public struct IndexStoreMatch: Sendable, Equatable {
    public let path: String
    public let score: Double

    public init(path: String, score: Double) {
        self.path = path
        self.score = score
    }
}

/// A dedicated parser and ranker for Apple's binary DeveloperDocumentation.index (`store.db`) files.
public struct IndexStoreReader: Sendable {
    public static let defaultMaxPathLength: Int = 240

    public let maxPathLength: Int

    public init(maxPathLength: Int = defaultMaxPathLength) {
        self.maxPathLength = maxPathLength
    }

    /// Checks whether an isolated alphanumeric token exists in the binary index data.
    public func containsToken(_ token: String, in data: Data) -> Bool {
        guard let needle = token.data(using: .utf8), !needle.isEmpty else { return false }
        let moduleCharacterSet = CharacterSet.alphanumerics

        var searchRange = 0..<data.count
        while let matchRange = data.range(of: needle, options: [], in: searchRange) {
            let lowerBound = matchRange.lowerBound
            let upperBound = matchRange.upperBound
            let hasLeadingBoundary = lowerBound == data.startIndex || !isModuleByte(data[lowerBound - 1], moduleCharacterSet: moduleCharacterSet)
            let hasTrailingBoundary = upperBound == data.endIndex || !isModuleByte(data[upperBound], moduleCharacterSet: moduleCharacterSet)
            if hasLeadingBoundary && hasTrailingBoundary {
                return true
            }

            searchRange = upperBound..<data.count
        }

        return false
    }

    /// Determines if a raw byte represents an alphanumeric module character.
    public func isModuleByte(_ byte: UInt8, moduleCharacterSet: CharacterSet = .alphanumerics) -> Bool {
        guard let scalar = UnicodeScalar(Int(byte)) else { return false }
        return moduleCharacterSet.contains(scalar)
    }

    /// Determines if a raw byte represents a valid character in a documentation URL path.
    public func isPathByte(_ byte: UInt8) -> Bool {
        switch byte {
        case 48...57, 65...90, 97...122, 45, 46, 47, 95:
            // 0-9, A-Z, a-z, '-', '.', '/', '_'
            return true
        default:
            return false
        }
    }

    /// Tokenizes a search query into normalized lowercase alphanumeric components.
    public func tokenize(query: String) -> [String] {
        query
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    /// Computes a relevance score for a given documentation path against query tokens.
    public func scoreForPath(_ path: String, tokens: [String]) -> Double {
        let lower = path.lowercased()
        var score = 0.0
        var matchedCount = 0
        for token in tokens {
            if lower.hasSuffix("/\(token)") { score += 50 }
            if lower.contains("/\(token)") { score += 20 }
            if lower.contains(token) {
                score += 10
                matchedCount += 1
            }
        }
        if matchedCount == 0 { return 0 }
        score += Double(matchedCount) * 15
        score -= Double(path.count) * 0.01
        return score
    }

    /// Extracts and scores `/documentation/...` paths from raw index store data against tokens.
    public func rankDocumentationPaths(in data: Data, tokens: [String], limit: Int = 50) -> [IndexStoreMatch] {
        guard !tokens.isEmpty else { return [] }

        let prefix = Data(DocumentationPath.prefix.utf8)
        var matches = Set<String>()
        var ranked: [IndexStoreMatch] = []

        var searchStart = data.startIndex
        while searchStart < data.endIndex,
              let matchRange = data.range(of: prefix, options: [], in: searchStart..<data.endIndex) {
            var end = matchRange.upperBound
            while end < data.endIndex && end - matchRange.lowerBound < maxPathLength && isPathByte(data[end]) {
                end += 1
            }

            let candidate = data[matchRange.lowerBound..<end]
            if candidate.count > prefix.count + 1,
               let path = String(data: candidate, encoding: .utf8),
               matches.insert(path).inserted {
                let score = scoreForPath(path, tokens: tokens)
                if score > 0 {
                    ranked.append(IndexStoreMatch(path: path, score: score))
                }
            }

            searchStart = matchRange.upperBound
        }

        return ranked
            .sorted { lhs, rhs in
                if lhs.score == rhs.score { return lhs.path < rhs.path }
                return lhs.score > rhs.score
            }
            .prefix(limit)
            .map { $0 }
    }

    /// High-level search interface: tokenizes the query and ranks matching paths from raw index data.
    public func search(query: String, in data: Data, limit: Int = 50) -> [IndexStoreMatch] {
        let tokens = tokenize(query: query)
        guard !tokens.isEmpty else { return [] }
        return rankDocumentationPaths(in: data, tokens: tokens, limit: limit)
    }

    /// Derives a user-friendly title from a documentation path.
    public func title(from path: String) -> String {
        let components = path.split(separator: "/")
        guard let raw = components.last else { return path }
        let normalized = raw.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
        return normalized
    }
}
