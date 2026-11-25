import Foundation
import iDocsTelemetry

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

    /// Mutable evidence accumulated as the resolver walks its phases. Direct-path
    /// resolution and the search fallback both append to these and a final
    /// unresolved result reports whatever they gathered.
    private struct Accumulator {
        var candidates: [ResolveDocsCandidate] = []
        var resolveDiagnostics: [ResolveDocsDiagnostic] = []
        var fetchDiagnostics: [FetchSourceAttempt] = []
    }

    public func run(intent: ResolveDocsIntent) async throws -> ResolveDocsResult {
        try await iDocsTelemetry.withSpan("idocs.resolve.pipeline") {
            if let validationError = intent.validationErrorMessage {
                throw ResolveDocsError.invalidIntent(validationError)
            }

            var accumulator = Accumulator()

            if let resolved = await resolveDirectPaths(intent: intent, accumulator: &accumulator) {
                recordResolveDiagnostics(resolved.resolveDiagnostics)
                iDocsTelemetry.setAttributes([
                    "idocs.result.count": .int(1),
                    "idocs.source": .string(resolved.evidence?.source.rawValue ?? "none")
                ])
                return resolved
            }

            if let resolved = await resolveSearchFallback(intent: intent, accumulator: &accumulator) {
                recordResolveDiagnostics(resolved.resolveDiagnostics)
                iDocsTelemetry.setAttributes([
                    "idocs.result.count": .int(1),
                    "idocs.source": .string(resolved.evidence?.source.rawValue ?? "none")
                ])
                return resolved
            }

            accumulator.resolveDiagnostics.append(
                ResolveDocsDiagnostic(
                    stage: "resolve",
                    status: "unresolved",
                    reason: "no_fetch_verified_candidate"
                )
            )
            recordResolveDiagnostics(accumulator.resolveDiagnostics)
            iDocsTelemetry.setAttributes([
                "idocs.result.count": .int(0),
                "idocs.source": .string("none")
            ])
            return ResolveDocsResult(
                canonicalPath: nil,
                confidence: .unresolved,
                verifiedByFetch: false,
                evidence: nil,
                candidates: accumulator.candidates,
                resolveDiagnostics: accumulator.resolveDiagnostics,
                fetchDiagnostics: accumulator.fetchDiagnostics.isEmpty ? nil : accumulator.fetchDiagnostics
            )
        }
    }

    /// Tries each derived direct path in order, returning a high-confidence result
    /// on the first fetch-verified, member-kind-matching hit. Misses and mismatches
    /// are recorded as candidates/diagnostics and resolution continues.
    private func resolveDirectPaths(
        intent: ResolveDocsIntent,
        accumulator: inout Accumulator
    ) async -> ResolveDocsResult? {
        for path in directPaths(for: intent) {
            do {
                let output = try await fetch(path)
                let evidence = evidenceFromFetch(output, path: path, sourceFamily: intent.sourceFamily)
                let allFetchDiagnostics = accumulator.fetchDiagnostics + output.sourceAttempts
                if let mismatch = fetchMismatch(evidence, attemptedPath: path, intent: intent, checkMemberKind: true) {
                    accumulator.fetchDiagnostics = allFetchDiagnostics
                    accumulator.candidates.append(
                        ResolveDocsCandidate(
                            path: evidence.path,
                            title: evidence.title,
                            source: .direct,
                            matchQuality: .mismatch,
                            verifiedByFetch: true,
                            confidence: .low
                        )
                    )
                    accumulator.resolveDiagnostics.append(
                        ResolveDocsDiagnostic(
                            stage: "direct_path",
                            status: "miss",
                            reason: mismatch,
                            hint: mismatch == "member_kind_mismatch"
                                ? "Fetched evidence did not match the requested member kind."
                                : "Fetched evidence identified a different documentation path.",
                            pathAttempt: path
                        )
                    )
                    continue
                }
                accumulator.candidates.append(
                    ResolveDocsCandidate(
                        path: evidence.path,
                        title: evidence.title,
                        source: .direct,
                        matchQuality: .exact,
                        verifiedByFetch: true,
                        confidence: .high
                    )
                )
                accumulator.resolveDiagnostics.append(
                    ResolveDocsDiagnostic(
                        stage: "direct_path",
                        status: "hit",
                        reason: "fetch_verified",
                        pathAttempt: path
                    )
                )
                return makeResolvedResult(
                    confidence: .high,
                    evidence: evidence,
                    accumulator: accumulator,
                    fetchDiagnostics: allFetchDiagnostics
                )
            } catch {
                let attempts = fetchAttempts(from: error)
                if !attempts.isEmpty {
                    accumulator.fetchDiagnostics.append(contentsOf: attempts)
                }
                accumulator.candidates.append(
                    ResolveDocsCandidate(
                        path: path,
                        title: nil,
                        source: .direct,
                        matchQuality: .exact,
                        verifiedByFetch: false,
                        confidence: .low
                    )
                )
                accumulator.resolveDiagnostics.append(
                    ResolveDocsDiagnostic(
                        stage: "direct_path",
                        status: "miss",
                        reason: failureReason(for: error),
                        pathAttempt: path
                    )
                )
            }
        }
        return nil
    }

    /// Runs the search fallback, fetch-verifying recovered candidates. Returns the
    /// first verified candidate that satisfies the intent's exactness requirement;
    /// otherwise records candidates/diagnostics and returns nil.
    private func resolveSearchFallback(
        intent: ResolveDocsIntent,
        accumulator: inout Accumulator
    ) async -> ResolveDocsResult? {
        let fallbackQuery = searchQuery(for: intent)
        do {
            let results = try await search(fallbackQuery)
            accumulator.resolveDiagnostics.append(
                ResolveDocsDiagnostic(
                    stage: "search_fallback",
                    status: results.isEmpty ? "miss" : "hit",
                    reason: results.isEmpty ? "no_candidates" : "candidate_recovery",
                    queryAttempt: fallbackQuery
                )
            )

            for result in results where result.fetchSupported {
                let searchQuality = matchQuality(path: result.path, title: result.title, intent: intent)
                guard searchQuality != .mismatch else { continue }

                do {
                    let output = try await fetch(result.path)
                    let evidence = evidenceFromFetch(output, path: result.path, sourceFamily: intent.sourceFamily)
                    let allFetchDiagnostics = accumulator.fetchDiagnostics + output.sourceAttempts
                    let mismatch = fetchMismatch(
                        evidence, attemptedPath: result.path, intent: intent, checkMemberKind: output.canonicalPath != nil
                    )
                    let quality = if mismatch != nil {
                        ResolveDocsMatchQuality.mismatch
                    } else if output.canonicalPath != nil {
                        matchQuality(path: evidence.path, title: evidence.title, intent: intent)
                    } else {
                        searchQuality
                    }
                    let confidence: ResolveDocsConfidence = quality == .exact ? .medium : .low
                    accumulator.candidates.append(
                        ResolveDocsCandidate(
                            path: evidence.path,
                            title: output.canonicalPath == nil ? result.title : evidence.title,
                            source: .searchFallback,
                            matchQuality: quality,
                            verifiedByFetch: true,
                            confidence: confidence
                        )
                    )
                    if let mismatch {
                        accumulator.resolveDiagnostics.append(ResolveDocsDiagnostic(
                            stage: "search_fallback", status: "miss", reason: mismatch, pathAttempt: result.path
                        ))
                    }
                    if quality == .mismatch || (requiresExactFallback(for: intent) && quality != .exact) {
                        accumulator.fetchDiagnostics = allFetchDiagnostics
                        continue
                    }
                    return makeResolvedResult(
                        confidence: confidence,
                        evidence: evidence,
                        accumulator: accumulator,
                        fetchDiagnostics: allFetchDiagnostics
                    )
                } catch {
                    let attempts = fetchAttempts(from: error)
                    if !attempts.isEmpty {
                        accumulator.fetchDiagnostics.append(contentsOf: attempts)
                    }
                    accumulator.candidates.append(
                        ResolveDocsCandidate(
                            path: result.path,
                            title: result.title,
                            source: .searchFallback,
                            matchQuality: searchQuality,
                            verifiedByFetch: false,
                            confidence: .low
                        )
                    )
                }
            }
        } catch {
            accumulator.resolveDiagnostics.append(
                ResolveDocsDiagnostic(
                    stage: "search_fallback",
                    status: "error",
                    reason: failureReason(for: error),
                    queryAttempt: fallbackQuery
                )
            )
        }
        return nil
    }

    /// Builds a fetch-verified resolved result from the accumulated evidence.
    private func makeResolvedResult(
        confidence: ResolveDocsConfidence,
        evidence: ResolveDocsEvidence,
        accumulator: Accumulator,
        fetchDiagnostics: [FetchSourceAttempt]
    ) -> ResolveDocsResult {
        ResolveDocsResult(
            canonicalPath: evidence.path,
            confidence: confidence,
            verifiedByFetch: true,
            evidence: evidence,
            candidates: accumulator.candidates,
            resolveDiagnostics: accumulator.resolveDiagnostics,
            fetchDiagnostics: fetchDiagnostics
        )
    }

    private func directPaths(for intent: ResolveDocsIntent) -> [String] {
        guard let framework = intent.framework else { return [] }
        let frameworkSlug = slug(framework)

        if let symbol = intent.symbol {
            return [DocumentationPath.make(frameworkSlug, slug(symbol))]
        }

        guard let type = intent.type else { return [] }
        if let member = intent.member {
            let baseSegments = [frameworkSlug, slug(type)]
            let memberSlug = slug(member)
            let direct = DocumentationPath.make(baseSegments + [memberSlug])
            let knownAliases = knownMemberAliases(framework: framework, type: type, member: member)
            let signatureGuesses = signatureCandidates(memberSlug: memberSlug, memberKind: intent.memberKind)
            let memberCandidates = (knownAliases + signatureGuesses).map { DocumentationPath.make(baseSegments + [$0]) }
            return uniquePaths([direct] + memberCandidates)
        }
        return [DocumentationPath.make(frameworkSlug, slug(type))]
    }

    private func knownMemberAliases(framework: String, type: String, member: String) -> [String] {
        let key = [framework, type, member].map(compact).joined(separator: "/")
        return ResolveDocsMemberAliases.slugs(forKey: key)
    }

    /// Apple renders callable members with their signature in the path slug
    /// (e.g. `navigationtitle(_:)`), and disambiguates Swift properties or methods
    /// in dual-language frameworks with `-swift.property` or `-swift.method`, so the
    /// bare slug 404s in those cases.
    /// Generate the common signature and disambiguation forms based on member kind.
    /// These are only guesses: fetch verification stays the correctness gate, and a miss
    /// falls through to the search fallback exactly as before. Labeled-argument signatures
    /// still rely on `knownMemberAliases` or the search fallback. Takes the already-slugged
    /// member to avoid recomputing `slug(member)`.
    private func signatureCandidates(memberSlug: String, memberKind: String?) -> [String] {
        guard let memberKind = memberKind?.lowercased() else {
            return [
                "\(memberSlug)(_:)",
                "\(memberSlug)()",
                "\(memberSlug)-swift.property",
                "\(memberSlug)-swift.method"
            ]
        }
        switch memberKind {
        case "method", "function", "initializer":
            return [
                "\(memberSlug)(_:)",
                "\(memberSlug)()",
                "\(memberSlug)-swift.method",
                "\(memberSlug)-swift.type.method"
            ]
        case "property", "variable":
            return [
                "\(memberSlug)-swift.property",
                "\(memberSlug)-swift.type.property"
            ]
        case "type_property", "typeproperty":
            return [
                "\(memberSlug)-swift.type.property",
                "\(memberSlug)-swift.property"
            ]
        case "type_method", "typemethod":
            return [
                "\(memberSlug)-swift.type.method",
                "\(memberSlug)-swift.method"
            ]
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

    private func matchQuality(path: String, title: String, intent: ResolveDocsIntent) -> ResolveDocsMatchQuality {
        let candidate = compact("\(path) \(title)")
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

    private func fetchMismatch(
        _ evidence: ResolveDocsEvidence, attemptedPath: String, intent: ResolveDocsIntent, checkMemberKind: Bool
    ) -> String? {
        guard matchesAttemptedPath(evidence, attemptedPath: attemptedPath) else {
            return "canonical_path_mismatch"
        }
        if checkMemberKind && !memberKindMatches(evidence: evidence, intent: intent) {
            return "member_kind_mismatch"
        }
        return nil
    }

    private func matchesAttemptedPath(_ evidence: ResolveDocsEvidence, attemptedPath: String) -> Bool {
        if evidence.path == attemptedPath { return true }

        let decodedAttempt = attemptedPath.removingPercentEncoding ?? attemptedPath
        let attempted = DocumentationPath.canonicalPagePath(from: decodedAttempt) ?? decodedAttempt.lowercased()
        let reported = evidence.path.lowercased()
        guard reported.hasPrefix(attempted) else { return false }

        // A short slug can acquire a signature or disambiguation suffix for the same symbol.
        let suffix = reported.dropFirst(attempted.count)
        guard !suffix.contains("/") else { return false }
        let disambiguation: Substring
        if suffix.first == "(" {
            guard let signatureEnd = suffix.lastIndex(of: ")") else { return false }
            disambiguation = suffix[suffix.index(after: signatureEnd)...]
        } else {
            disambiguation = suffix
        }

        if disambiguation.isEmpty { return true }
        let token = disambiguation.dropFirst()
        guard disambiguation.first == "-", !token.isEmpty,
              token.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-") })
        else { return false }

        if token.hasPrefix("swift.") || token.hasPrefix("occ.") { return true }
        // An unqualified suffix can also be part of an article slug. Require the symbol title to match.
        guard let attemptedSlug = attempted.split(separator: "/").last else { return false }
        return slug(evidence.title) == slug(String(attemptedSlug))
    }

    private func memberKindMatches(evidence: ResolveDocsEvidence, intent: ResolveDocsIntent) -> Bool {
        guard let memberKind = intent.memberKind?.lowercased(),
              intent.member != nil else {
            return true
        }

        let combined = "\(evidence.path) \(evidence.title)".lowercased()
        let memberPath = evidence.path.split(separator: "/").last?.lowercased() ?? ""
        let memberParts = memberPath.split(separator: "-", maxSplits: 2)
        let isObjectiveCSelector = memberParts.first?.hasSuffix(":") == true
        let kind = memberParts.dropFirst().first ?? ""
        let isObjectiveCMethod = ["c.method", "c.type.method", "occ.method", "occ.type.method"].contains(kind)
        let looksCallable = isObjectiveCSelector || isObjectiveCMethod || combined.contains("(")
            || combined.contains("-swift.method") || combined.contains("-swift.type.method")
        let looksProperty = combined.contains("-swift.property") || combined.contains("-swift.type.property")
        switch memberKind {
        case "method", "function", "initializer", "type_method", "typemethod":
            return looksCallable && !looksProperty
        case "property", "variable", "type_property", "typeproperty":
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
            path: output.canonicalPath ?? path,
            title: MarkdownSummary.title(from: output.markdown, fallback: path),
            summary: MarkdownSummary.summary(from: output.markdown)
        )
    }

    private func recordResolveDiagnostics(_ diagnostics: [ResolveDocsDiagnostic]) {
        for diagnostic in diagnostics {
            var attributes: [String: TelemetryAttributeValue] = [
                "idocs.stage.name": .string(diagnostic.stage),
                "idocs.stage.status": .string(diagnostic.status)
            ]
            if let reason = diagnostic.reason {
                attributes["idocs.stage.reason_code"] = .string(
                    iDocsTelemetry.reasonCode(reason)
                )
            }
            iDocsTelemetry.addEvent("idocs.resolve.stage", attributes: attributes)
        }
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
