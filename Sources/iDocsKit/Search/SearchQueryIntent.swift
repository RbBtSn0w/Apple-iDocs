import Foundation

struct SearchQueryIntent: Sendable {
    struct RequiredSymbol: Sendable {
        let compact: String
        let tokenStems: Set<String>
    }

    private static let stopWords: Set<String> = [
        "how", "do", "does", "can", "i", "we", "you", "a", "an", "the",
        "to", "in", "on", "for", "with", "and", "or", "of", "my", "your",
        "is", "are", "be", "by", "from", "using", "use"
    ]

    private static let technologyCompacts: Set<String> = [
        "swiftui", "uikit", "appkit", "foundation", "xcode", "appstoreconnect", "testflight",
        "coregraphics", "coredata", "swiftdata", "combine", "dispatch"
    ]

    let rawQuery: String
    let rawSegments: [String]
    let compactQuery: String
    let tokenStems: [String]
    let requiredSymbols: [RequiredSymbol]

    init(_ query: String) {
        self.rawQuery = query
        self.rawSegments = Self.segments(in: query)
        self.compactQuery = Self.compact(query)

        let tokens = Self.lexicalTokens(in: query)
            .filter { !Self.stopWords.contains($0) }
        self.tokenStems = Self.stableUnique(tokens.map(Self.stem))

        self.requiredSymbols = Self.segments(in: query).compactMap { segment in
            let compact = Self.compact(segment)
            guard !compact.isEmpty,
                  !Self.technologyCompacts.contains(compact),
                  Self.looksLikeCodeSymbol(segment) else {
                return nil
            }

            let stems = Set(Self.lexicalTokens(in: segment).map(Self.stem))
            return RequiredSymbol(compact: compact, tokenStems: stems)
        }
    }

    func matches(technology: Technology) -> Bool {
        let queryTokenSet = Set(tokenStems)
        let nameTokens = Set(Self.lexicalTokens(in: technology.name).map(Self.stem))
        let pathTokens = Set(Self.technologyPathTokens(in: technology.url).map(Self.stem))

        if !nameTokens.isEmpty && nameTokens.isSubset(of: queryTokenSet) {
            return true
        }

        return !pathTokens.isDisjoint(with: queryTokenSet)
    }

    func acceptsRemoteResult(_ result: SearchResult) -> Bool {
        acceptsCandidate(title: result.title, path: result.path, abstract: result.abstract)
    }

    func acceptsCandidate(title: String, path: String, abstract: String? = nil) -> Bool {
        guard !requiredSymbols.isEmpty else { return true }

        let compactTitle = Self.compact(title)
        let compactPath = Self.compact(path)
        let compactAbstract = Self.compact(abstract ?? "")
        let candidateStems = Set(
            (Self.lexicalTokens(in: title) + Self.lexicalTokens(in: path) + Self.lexicalTokens(in: abstract ?? ""))
                .map(Self.stem)
        )

        return requiredSymbols.contains { symbol in
            compactTitle.contains(symbol.compact)
                || compactPath.contains(symbol.compact)
                || compactAbstract.contains(symbol.compact)
                || symbol.tokenStems.isSubset(of: candidateStems)
        }
    }

    func score(result: SearchResult) -> Double {
        score(
            title: result.title,
            path: result.path,
            abstract: result.abstract,
            sourceKind: result.sourceKind,
            fetchSupported: result.fetchSupported,
            matchScope: result.matchScope,
            baseRelevance: result.relevance
        )
    }

    func score(
        title: String,
        path: String,
        abstract: String?,
        sourceKind: AppleSourceKind,
        fetchSupported: Bool,
        matchScope: SearchMatchScope,
        baseRelevance: Double? = nil
    ) -> Double {
        let titleStems = Set(Self.lexicalTokens(in: title).map(Self.stem))
        let pathStems = Set(Self.lexicalTokens(in: path).map(Self.stem))
        let abstractStems = Set(Self.lexicalTokens(in: abstract ?? "").map(Self.stem))
        let compactTitle = Self.compact(title)
        let compactPath = Self.compact(path)

        var score = baseRelevance ?? 0

        if title == rawQuery {
            score += 180
        }
        if compactTitle == compactQuery {
            score += 120
        }
        if compactPath.hasSuffix(compactQuery) {
            score += 80
        }

        for token in tokenStems {
            if titleStems.contains(token) { score += 18 }
            if pathStems.contains(token) { score += 12 }
            if abstractStems.contains(token) { score += 4 }
        }

        let titleAndPathStems = titleStems.union(pathStems)
        for symbol in requiredSymbols {
            if compactTitle.contains(symbol.compact) {
                score += 220
            } else if compactPath.contains(symbol.compact) {
                score += 180
            } else {
                let overlap = symbol.tokenStems.intersection(titleAndPathStems).count
                if overlap > 0 {
                    score += Double(overlap) / Double(max(symbol.tokenStems.count, 1)) * 80
                }
            }
        }

        switch sourceKind {
        case .documentation, .help:
            score += 30
        case .video, .news, .marketing, .unknown:
            score -= 80
        }

        if fetchSupported {
            score += 20
        } else {
            score -= 40
        }

        if !requiredSymbols.isEmpty {
            switch matchScope {
            case .symbol, .member:
                score += 35
            case .module:
                score -= 90
            case .path:
                break
            }
        }

        score -= Double(extraTitleTokenCount(in: title)) * 14
        score -= Double(documentationPathDepth(path)) * 3
        return score
    }

    private func extraTitleTokenCount(in title: String) -> Int {
        let comparableTitle = title.split(separator: "(", maxSplits: 1).first.map(String.init) ?? title
        let titleStems = Set(Self.lexicalTokens(in: comparableTitle).map(Self.stem))
        return max(0, titleStems.subtracting(Set(tokenStems)).count)
    }

    private func documentationPathDepth(_ path: String) -> Int {
        URLHelpers.normalizePath(path).split(separator: "/").count
    }

    static func compact(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    static func lexicalTokens(in text: String) -> [String] {
        var tokens: [String] = []
        for segment in segments(in: text) {
            let compactSegment = compact(segment)
            if !compactSegment.isEmpty {
                tokens.append(compactSegment)
            }
            for piece in splitIdentifier(segment) {
                let compactPiece = compact(piece)
                if !compactPiece.isEmpty {
                    tokens.append(compactPiece)
                }
            }
        }
        return stableUnique(tokens)
    }

    static func stem(_ token: String) -> String {
        if token.count > 3, token.hasSuffix("ies") {
            return String(token.dropLast(3)) + "y"
        }
        if token.count > 3, token.hasSuffix("s") {
            return String(token.dropLast())
        }
        return token
    }

    private static func segments(in text: String) -> [String] {
        text.split { character in
            !character.isLetter && !character.isNumber
        }
        .map(String.init)
        .filter { !$0.isEmpty }
    }

    private static func technologyPathTokens(in path: String) -> [String] {
        let components = URLHelpers.normalizePath(path)
            .split(separator: "/")
            .map(String.init)
            .filter { $0.lowercased() != "documentation" }
        return lexicalTokens(in: components.joined(separator: " "))
    }

    private static func splitIdentifier(_ value: String) -> [String] {
        let characters = Array(value)
        guard !characters.isEmpty else { return [] }

        var pieces: [String] = []
        var current = String(characters[0])

        for index in characters.indices.dropFirst() {
            let previous = characters[index - 1]
            let character = characters[index]
            let next = index + 1 < characters.count ? characters[index + 1] : nil

            if shouldBreakIdentifier(previous: previous, current: character, next: next) {
                pieces.append(current)
                current = String(character)
            } else {
                current.append(character)
            }
        }

        pieces.append(current)
        return pieces
    }

    private static func shouldBreakIdentifier(previous: Character, current: Character, next: Character?) -> Bool {
        if isDigit(previous) != isDigit(current) {
            return true
        }
        if (isLowercase(previous) || isDigit(previous)) && isUppercase(current) {
            return true
        }
        if isUppercase(previous), isUppercase(current), let next, isLowercase(next) {
            return true
        }
        return false
    }

    private static func looksLikeCodeSymbol(_ segment: String) -> Bool {
        let compactSegment = compact(segment)
        guard compactSegment.count >= 3 else { return false }
        if segment.rangeOfCharacter(from: .decimalDigits) != nil {
            return true
        }
        let pieces = splitIdentifier(segment)
        return pieces.count > 1
            && segment.rangeOfCharacter(from: .uppercaseLetters) != nil
            && segment.rangeOfCharacter(from: .lowercaseLetters) != nil
    }

    private static func isUppercase(_ character: Character) -> Bool {
        String(character).rangeOfCharacter(from: .uppercaseLetters) != nil
    }

    private static func isLowercase(_ character: Character) -> Bool {
        String(character).rangeOfCharacter(from: .lowercaseLetters) != nil
    }

    private static func isDigit(_ character: Character) -> Bool {
        String(character).rangeOfCharacter(from: .decimalDigits) != nil
    }

    private static func stableUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}

struct SearchResultRanker: Sendable {
    let intent: SearchQueryIntent

    init(query: String) {
        self.intent = SearchQueryIntent(query)
    }

    init(intent: SearchQueryIntent) {
        self.intent = intent
    }

    func rankedRemoteResults(_ results: [SearchResult]) -> [SearchResult] {
        results
            .filter(intent.acceptsRemoteResult)
            .sorted { left, right in
                let leftScore = intent.score(result: left)
                let rightScore = intent.score(result: right)
                if leftScore == rightScore {
                    return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
                }
                return leftScore > rightScore
            }
    }
}
