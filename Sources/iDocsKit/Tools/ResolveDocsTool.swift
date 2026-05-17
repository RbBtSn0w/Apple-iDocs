import Foundation

public enum ResolveDocsConfidence: String, Sendable, Codable, Equatable {
    case high
    case medium
    case low
    case unresolved
}

public enum ResolveDocsCandidateSource: String, Sendable, Codable, Equatable {
    case direct
    case searchFallback = "search_fallback"
}

public enum ResolveDocsMatchQuality: String, Sendable, Codable, Equatable {
    case exact
    case partial
    case mismatch
    case unknown
}

public enum ResolveDocsError: Error, Equatable, LocalizedError {
    case invalidIntent(String)

    public var errorDescription: String? {
        switch self {
        case .invalidIntent(let message):
            return "Invalid resolve intent: \(message)"
        }
    }
}

public struct ResolveDocsIntent: Sendable, Codable, Equatable {
    public let framework: String?
    public let symbol: String?
    public let type: String?
    public let member: String?
    public let memberKind: String?
    public let sourceFamily: String

    public init(
        framework: String? = nil,
        symbol: String? = nil,
        type: String? = nil,
        member: String? = nil,
        memberKind: String? = nil,
        sourceFamily: String? = nil
    ) {
        self.framework = Self.trimmed(framework)
        self.symbol = Self.trimmed(symbol)
        self.type = Self.trimmed(type)
        self.member = Self.trimmed(member)
        self.memberKind = Self.trimmed(memberKind)
        self.sourceFamily = Self.trimmed(sourceFamily) ?? "documentation"
    }

    var validationErrorMessage: String? {
        guard framework != nil else {
            return "framework is required"
        }

        guard sourceFamily == "documentation" else {
            return "source-family must be documentation"
        }

        if member != nil && type == nil {
            return "member requires type"
        }

        if symbol != nil && (type != nil || member != nil) {
            return "symbol cannot be combined with type or member"
        }

        if symbol != nil || type != nil {
            return nil
        }

        return "one of symbol or type is required"
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public struct ResolveDocsEvidence: Sendable, Codable, Equatable {
    public let sourceFamily: String
    public let source: DataSource
    public let path: String
    public let title: String
    public let summary: String?

    public init(
        sourceFamily: String,
        source: DataSource,
        path: String,
        title: String,
        summary: String? = nil
    ) {
        self.sourceFamily = sourceFamily
        self.source = source
        self.path = path
        self.title = title
        self.summary = summary
    }
}

public struct ResolveDocsCandidate: Sendable, Codable, Equatable {
    public let path: String
    public let title: String?
    public let source: ResolveDocsCandidateSource
    public let matchQuality: ResolveDocsMatchQuality
    public let verifiedByFetch: Bool
    public let confidence: ResolveDocsConfidence

    public init(
        path: String,
        title: String?,
        source: ResolveDocsCandidateSource,
        matchQuality: ResolveDocsMatchQuality,
        verifiedByFetch: Bool,
        confidence: ResolveDocsConfidence
    ) {
        self.path = path
        self.title = title
        self.source = source
        self.matchQuality = matchQuality
        self.verifiedByFetch = verifiedByFetch
        self.confidence = confidence
    }
}

public struct ResolveDocsDiagnostic: Sendable, Codable, Equatable {
    public let stage: String
    public let status: String
    public let reason: String?
    public let hint: String?
    public let pathAttempt: String?
    public let queryAttempt: String?

    public init(
        stage: String,
        status: String,
        reason: String? = nil,
        hint: String? = nil,
        pathAttempt: String? = nil,
        queryAttempt: String? = nil
    ) {
        self.stage = stage
        self.status = status
        self.reason = reason
        self.hint = hint
        self.pathAttempt = pathAttempt
        self.queryAttempt = queryAttempt
    }
}

public struct ResolveDocsResult: Sendable, Codable, Equatable {
    public let canonicalPath: String?
    public let confidence: ResolveDocsConfidence
    public let verifiedByFetch: Bool
    public let evidence: ResolveDocsEvidence?
    public let candidates: [ResolveDocsCandidate]
    public let resolveDiagnostics: [ResolveDocsDiagnostic]
    public let fetchDiagnostics: [FetchSourceAttempt]?

    public init(
        canonicalPath: String?,
        confidence: ResolveDocsConfidence,
        verifiedByFetch: Bool,
        evidence: ResolveDocsEvidence?,
        candidates: [ResolveDocsCandidate],
        resolveDiagnostics: [ResolveDocsDiagnostic],
        fetchDiagnostics: [FetchSourceAttempt]? = nil
    ) {
        self.canonicalPath = canonicalPath
        self.confidence = confidence
        self.verifiedByFetch = verifiedByFetch
        self.evidence = evidence
        self.candidates = candidates
        self.resolveDiagnostics = resolveDiagnostics
        self.fetchDiagnostics = fetchDiagnostics
    }
}

public struct ResolveDocsTool {
    private let fetch: (String) async throws -> FetchDocResult
    private let search: (String) async throws -> [SearchResult]

    public init(
        fetch: @escaping (String) async throws -> FetchDocResult,
        search: @escaping (String) async throws -> [SearchResult] = { _ in [] }
    ) {
        self.fetch = fetch
        self.search = search
    }

    public init(fetchTool: FetchDocTool = FetchDocTool(), searchTool: SearchDocsTool = SearchDocsTool()) {
        self.fetch = { path in
            try await fetchTool.runDetailed(path: path)
        }
        self.search = { query in
            try await searchTool.run(query: query)
        }
    }

    public func run(intent: ResolveDocsIntent) async throws -> ResolveDocsResult {
        if let validationError = intent.validationErrorMessage {
            throw ResolveDocsError.invalidIntent(validationError)
        }

        var candidates: [ResolveDocsCandidate] = []
        var resolveDiagnostics: [ResolveDocsDiagnostic] = []
        var fetchDiagnostics: [FetchSourceAttempt] = []

        for path in directPaths(for: intent) {
            do {
                let output = try await fetch(path)
                let evidence = evidenceFromFetch(output, path: path, sourceFamily: intent.sourceFamily)
                let allFetchDiagnostics = fetchDiagnostics + output.sourceAttempts
                guard memberKindMatches(evidence: evidence, path: path, intent: intent) else {
                    fetchDiagnostics = allFetchDiagnostics
                    candidates.append(
                        ResolveDocsCandidate(
                            path: path,
                            title: evidence.title,
                            source: .direct,
                            matchQuality: .mismatch,
                            verifiedByFetch: true,
                            confidence: .low
                        )
                    )
                    resolveDiagnostics.append(
                        ResolveDocsDiagnostic(
                            stage: "direct_path",
                            status: "miss",
                            reason: "member_kind_mismatch",
                            hint: "Fetched evidence did not match the requested member kind.",
                            pathAttempt: path
                        )
                    )
                    continue
                }
                let candidate = ResolveDocsCandidate(
                    path: path,
                    title: evidence.title,
                    source: .direct,
                    matchQuality: .exact,
                    verifiedByFetch: true,
                    confidence: .high
                )
                candidates.append(candidate)
                resolveDiagnostics.append(
                    ResolveDocsDiagnostic(
                        stage: "direct_path",
                        status: "hit",
                        reason: "fetch_verified",
                        pathAttempt: path
                    )
                )
                return ResolveDocsResult(
                    canonicalPath: path,
                    confidence: .high,
                    verifiedByFetch: true,
                    evidence: evidence,
                    candidates: candidates,
                    resolveDiagnostics: resolveDiagnostics,
                    fetchDiagnostics: allFetchDiagnostics
                )
            } catch {
                let attempts = fetchAttempts(from: error)
                if !attempts.isEmpty {
                    fetchDiagnostics.append(contentsOf: attempts)
                }
                candidates.append(
                    ResolveDocsCandidate(
                        path: path,
                        title: nil,
                        source: .direct,
                        matchQuality: .exact,
                        verifiedByFetch: false,
                        confidence: .low
                    )
                )
                resolveDiagnostics.append(
                    ResolveDocsDiagnostic(
                        stage: "direct_path",
                        status: "miss",
                        reason: failureReason(for: error),
                        pathAttempt: path
                    )
                )
            }
        }

        let fallbackQuery = searchQuery(for: intent)
        do {
            let results = try await search(fallbackQuery)
            resolveDiagnostics.append(
                ResolveDocsDiagnostic(
                    stage: "search_fallback",
                    status: results.isEmpty ? "miss" : "hit",
                    reason: results.isEmpty ? "no_candidates" : "candidate_recovery",
                    queryAttempt: fallbackQuery
                )
            )

            for result in results where result.fetchSupported {
                let quality = matchQuality(for: result, intent: intent)
                guard quality != .mismatch else { continue }

                do {
                    let output = try await fetch(result.path)
                    let evidence = evidenceFromFetch(output, path: result.path, sourceFamily: intent.sourceFamily)
                    let allFetchDiagnostics = fetchDiagnostics + output.sourceAttempts
                    let confidence: ResolveDocsConfidence = quality == .exact ? .medium : .low
                    candidates.append(
                        ResolveDocsCandidate(
                            path: result.path,
                            title: result.title,
                            source: .searchFallback,
                            matchQuality: quality,
                            verifiedByFetch: true,
                            confidence: confidence
                        )
                    )
                    if requiresExactFallback(for: intent) && quality != .exact {
                        fetchDiagnostics = allFetchDiagnostics
                        continue
                    }
                    return ResolveDocsResult(
                        canonicalPath: result.path,
                        confidence: confidence,
                        verifiedByFetch: true,
                        evidence: evidence,
                        candidates: candidates,
                        resolveDiagnostics: resolveDiagnostics,
                        fetchDiagnostics: allFetchDiagnostics
                    )
                } catch {
                    let attempts = fetchAttempts(from: error)
                    if !attempts.isEmpty {
                        fetchDiagnostics.append(contentsOf: attempts)
                    }
                    candidates.append(
                        ResolveDocsCandidate(
                            path: result.path,
                            title: result.title,
                            source: .searchFallback,
                            matchQuality: quality,
                            verifiedByFetch: false,
                            confidence: .low
                        )
                    )
                }
            }
        } catch {
            resolveDiagnostics.append(
                ResolveDocsDiagnostic(
                    stage: "search_fallback",
                    status: "error",
                    reason: failureReason(for: error),
                    queryAttempt: fallbackQuery
                )
            )
        }

        resolveDiagnostics.append(
            ResolveDocsDiagnostic(
                stage: "resolve",
                status: "unresolved",
                reason: "no_fetch_verified_candidate"
            )
        )
        return ResolveDocsResult(
            canonicalPath: nil,
            confidence: .unresolved,
            verifiedByFetch: false,
            evidence: nil,
            candidates: candidates,
            resolveDiagnostics: resolveDiagnostics,
            fetchDiagnostics: fetchDiagnostics.isEmpty ? nil : fetchDiagnostics
        )
    }

    private func directPaths(for intent: ResolveDocsIntent) -> [String] {
        guard let framework = intent.framework else { return [] }
        let frameworkSlug = slug(framework)

        if let symbol = intent.symbol {
            return ["/documentation/\(frameworkSlug)/\(slug(symbol))"]
        }

        guard let type = intent.type else { return [] }
        if let member = intent.member {
            let base = "/documentation/\(frameworkSlug)/\(slug(type))"
            let direct = "\(base)/\(slug(member))"
            return uniquePaths([direct] + knownMemberAliases(framework: framework, type: type, member: member).map { "\(base)/\($0)" })
        }
        return ["/documentation/\(frameworkSlug)/\(slug(type))"]
    }

    private func knownMemberAliases(framework: String, type: String, member: String) -> [String] {
        let key = [framework, type, member].map(compact).joined(separator: "/")
        switch key {
        case "uikit/uiviewcontroller/present":
            return ["present(_:animated:completion:)"]
        default:
            return []
        }
    }

    private func uniquePaths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for path in paths where seen.insert(path).inserted {
            result.append(path)
        }
        return result
    }

    private func searchQuery(for intent: ResolveDocsIntent) -> String {
        [intent.framework, intent.symbol, intent.type, intent.member]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    private func matchQuality(for result: SearchResult, intent: ResolveDocsIntent) -> ResolveDocsMatchQuality {
        let candidate = compact("\(result.path) \(result.title)")
        guard let framework = intent.framework, candidate.contains(compact(framework)) else {
            return .mismatch
        }

        if let symbol = intent.symbol {
            return candidate.contains(compact(symbol)) ? .exact : .partial
        }

        if let type = intent.type, !candidate.contains(compact(type)) {
            return .mismatch
        }

        if let member = intent.member {
            return candidate.contains(compact(member)) ? .exact : .partial
        }

        return .exact
    }

    private func requiresExactFallback(for intent: ResolveDocsIntent) -> Bool {
        intent.symbol != nil || intent.member != nil
    }

    private func memberKindMatches(evidence: ResolveDocsEvidence, path: String, intent: ResolveDocsIntent) -> Bool {
        guard let memberKind = intent.memberKind?.lowercased(),
              intent.member != nil else {
            return true
        }

        let combined = "\(path) \(evidence.title)".lowercased()
        let looksCallable = combined.contains("(")
        switch memberKind {
        case "method", "function", "initializer":
            return looksCallable
        case "property", "variable":
            return !looksCallable
        default:
            return true
        }
    }

    private func evidenceFromFetch(
        _ output: FetchDocResult,
        path: String,
        sourceFamily: String
    ) -> ResolveDocsEvidence {
        ResolveDocsEvidence(
            sourceFamily: sourceFamily,
            source: output.source,
            path: path,
            title: title(from: output.markdown, fallback: path),
            summary: summary(from: output.markdown)
        )
    }

    private func title(from markdown: String, fallback: String) -> String {
        for line in markdown.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                return trimmed.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return fallback
    }

    private func summary(from markdown: String) -> String? {
        for line in markdown.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            return trimmed
        }
        return nil
    }

    private func fetchAttempts(from error: Error) -> [FetchSourceAttempt] {
        if let idocsError = error as? iDocsError {
            return idocsError.fetchAttempts
        }
        return []
    }

    private func failureReason(for error: Error) -> String {
        if let idocsError = error as? iDocsError {
            return idocsError.reason
        }
        if let resolveError = error as? ResolveDocsError {
            return resolveError.localizedDescription
        }
        return error.localizedDescription
    }

    private func slug(_ value: String) -> String {
        let head = value.split(separator: "(", maxSplits: 1).first.map(String.init) ?? value
        return compact(head)
    }

    private func compact(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
