import Foundation

public enum RetrievalSource: String, Sendable, Equatable {
    case cache
    case local
    case apple
    case help
    case sosumi
    case unsupported
}

public struct FetchAttemptDiagnostic: Sendable, Codable, Equatable {
    public let source: String
    public let status: String
    public let reason: String?
    public let contentType: String?
    public let statusCode: Int?
    public let hint: String?

    enum CodingKeys: String, CodingKey {
        case source
        case status
        case reason
        case contentType = "content_type"
        case statusCode = "status_code"
        case hint
    }

    public init(
        source: String,
        status: String,
        reason: String? = nil,
        contentType: String? = nil,
        statusCode: Int? = nil,
        hint: String? = nil
    ) {
        self.source = source
        self.status = status
        self.reason = reason
        self.contentType = contentType
        self.statusCode = statusCode
        self.hint = hint
    }
}

public struct DocumentationContent: Sendable, Equatable {
    public let title: String
    public let body: String
    public let metadata: [String: String]
    public let url: URL
    public let fetchDiagnostics: [FetchAttemptDiagnostic]?

    public init(
        title: String,
        body: String,
        metadata: [String: String] = [:],
        url: URL,
        fetchDiagnostics: [FetchAttemptDiagnostic]? = nil
    ) {
        self.title = title
        self.body = body
        self.metadata = metadata
        self.url = url
        self.fetchDiagnostics = fetchDiagnostics
    }
}

public struct SearchResult: Sendable, Equatable {
    public let id: String
    public let title: String
    public let snippet: String?
    public let technology: String
    public let source: RetrievalSource?
    public let sourceKind: String
    public let fetchSupported: Bool
    public let fetchSupportReason: String?
    public let matchScope: String
    public let queryAttempt: String?

    public init(
        id: String,
        title: String,
        snippet: String?,
        technology: String,
        source: RetrievalSource? = nil,
        sourceKind: String = "documentation",
        fetchSupported: Bool = true,
        fetchSupportReason: String? = nil,
        matchScope: String = "path",
        queryAttempt: String? = nil
    ) {
        self.id = id
        self.title = title
        self.snippet = snippet
        self.technology = technology
        self.source = source
        self.sourceKind = sourceKind
        self.fetchSupported = fetchSupported
        self.fetchSupportReason = fetchSupportReason
        self.matchScope = matchScope
        self.queryAttempt = queryAttempt
    }
}

public struct SearchStageDiagnostic: Sendable, Codable, Equatable {
    public let name: String
    public let status: String
    public let durationMs: Double
    public let resultCount: Int
    public let reason: String?
    public let hint: String?
    public let queryAttempt: String?

    enum CodingKeys: String, CodingKey {
        case name
        case status
        case durationMs = "duration_ms"
        case resultCount = "result_count"
        case reason
        case hint
        case queryAttempt = "query_attempt"
    }

    public init(
        name: String,
        status: String,
        durationMs: Double,
        resultCount: Int,
        reason: String? = nil,
        hint: String? = nil,
        queryAttempt: String? = nil
    ) {
        self.name = name
        self.status = status
        self.durationMs = durationMs
        self.resultCount = resultCount
        self.reason = reason
        self.hint = hint
        self.queryAttempt = queryAttempt
    }
}

public struct SearchDiagnostics: Sendable, Codable, Equatable {
    public let stages: [SearchStageDiagnostic]

    public init(stages: [SearchStageDiagnostic]) {
        self.stages = stages
    }
}

public struct DocumentationSearchResponse: Sendable, Equatable {
    public let results: [SearchResult]
    public let diagnostics: SearchDiagnostics?

    public init(results: [SearchResult], diagnostics: SearchDiagnostics? = nil) {
        self.results = results
        self.diagnostics = diagnostics
    }
}

public enum ResolveConfidence: String, Sendable, Codable, Equatable {
    case high
    case medium
    case low
    case unresolved
}

public enum ResolveCandidateSource: String, Sendable, Codable, Equatable {
    case direct
    case searchFallback = "search_fallback"
}

public enum ResolveMatchQuality: String, Sendable, Codable, Equatable {
    case exact
    case partial
    case mismatch
    case unknown
}

public struct ResolveIntent: Sendable, Codable, Equatable {
    public let framework: String?
    public let symbol: String?
    public let type: String?
    public let member: String?
    public let memberKind: String?
    public let sourceFamily: String

    enum CodingKeys: String, CodingKey {
        case framework
        case symbol
        case type
        case member
        case memberKind = "member_kind"
        case sourceFamily = "source_family"
    }

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

    public var validationErrorMessage: String? {
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

        if symbol != nil {
            return nil
        }

        if type != nil {
            return nil
        }

        return "one of symbol or type is required"
    }

    public var isValid: Bool {
        validationErrorMessage == nil
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public struct ResolveEvidence: Sendable, Codable, Equatable {
    public let sourceFamily: String
    public let source: String
    public let path: String
    public let title: String
    public let summary: String?

    enum CodingKeys: String, CodingKey {
        case sourceFamily = "source_family"
        case source
        case path
        case title
        case summary
    }

    public init(
        sourceFamily: String,
        source: String,
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

public struct ResolveCandidate: Sendable, Codable, Equatable {
    public let path: String
    public let title: String?
    public let source: ResolveCandidateSource
    public let matchQuality: ResolveMatchQuality
    public let verifiedByFetch: Bool
    public let confidence: ResolveConfidence

    enum CodingKeys: String, CodingKey {
        case path
        case title
        case source
        case matchQuality = "match_quality"
        case verifiedByFetch = "verified_by_fetch"
        case confidence
    }

    public init(
        path: String,
        title: String?,
        source: ResolveCandidateSource,
        matchQuality: ResolveMatchQuality,
        verifiedByFetch: Bool,
        confidence: ResolveConfidence
    ) {
        self.path = path
        self.title = title
        self.source = source
        self.matchQuality = matchQuality
        self.verifiedByFetch = verifiedByFetch
        self.confidence = confidence
    }
}

public struct ResolveDiagnostic: Sendable, Codable, Equatable {
    public let stage: String
    public let status: String
    public let reason: String?
    public let pathAttempt: String?
    public let queryAttempt: String?

    enum CodingKeys: String, CodingKey {
        case stage
        case status
        case reason
        case pathAttempt = "path_attempt"
        case queryAttempt = "query_attempt"
    }

    public init(
        stage: String,
        status: String,
        reason: String? = nil,
        pathAttempt: String? = nil,
        queryAttempt: String? = nil
    ) {
        self.stage = stage
        self.status = status
        self.reason = reason
        self.pathAttempt = pathAttempt
        self.queryAttempt = queryAttempt
    }
}

public struct ResolveResult: Sendable, Codable, Equatable {
    public let canonicalPath: String?
    public let confidence: ResolveConfidence
    public let verifiedByFetch: Bool
    public let evidence: ResolveEvidence?
    public let candidates: [ResolveCandidate]
    public let resolveDiagnostics: [ResolveDiagnostic]
    public let fetchDiagnostics: [FetchAttemptDiagnostic]

    enum CodingKeys: String, CodingKey {
        case canonicalPath = "canonical_path"
        case confidence
        case verifiedByFetch = "verified_by_fetch"
        case evidence
        case candidates
        case resolveDiagnostics = "resolve_diagnostics"
        case fetchDiagnostics = "fetch_diagnostics"
    }

    public init(
        canonicalPath: String?,
        confidence: ResolveConfidence,
        verifiedByFetch: Bool,
        evidence: ResolveEvidence?,
        candidates: [ResolveCandidate],
        resolveDiagnostics: [ResolveDiagnostic],
        fetchDiagnostics: [FetchAttemptDiagnostic]
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

public struct Technology: Sendable, Equatable {
    public let name: String
    public let id: String
    public let category: String?

    public init(name: String, id: String, category: String?) {
        self.name = name
        self.id = id
        self.category = category
    }
}
