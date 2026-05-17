import Foundation
import iDocsKit

public struct DefaultDocumentationAdapter: DocumentationService {
    private let adapterVersion: String
    private let logger: any DocumentationLogger
    private let searchPerformer: @Sendable (String, DocumentationConfig) async throws -> SearchDocsRunOutput
    private let resolvePerformer: @Sendable (ResolveIntent, DocumentationConfig) async throws -> ResolveDocsResult
    private let technologiesPerformer: @Sendable () async throws -> [Technology]
    private let usageRecorder: DocumentationUsageRecorder

    public init(
        adapterVersion: String = "1.0.0",
        logger: any DocumentationLogger = NoopDocumentationLogger(),
        searchPerformer: (@Sendable (String) async throws -> SearchDocsRunOutput)? = nil,
        configuredSearchPerformer: (@Sendable (String, DocumentationConfig) async throws -> SearchDocsRunOutput)? = nil,
        configuredResolvePerformer: (@Sendable (ResolveIntent, DocumentationConfig) async throws -> ResolveDocsResult)? = nil,
        technologiesPerformer: (@Sendable () async throws -> [Technology])? = nil,
        usageRecorder: DocumentationUsageRecorder = DocumentationUsageRecorder()
    ) throws {
        self.adapterVersion = adapterVersion
        self.logger = logger
        let defaultAppleAPI = AppleJSONAPI()
        let defaultSosumiAPI = SosumiAPI()
        self.searchPerformer = configuredSearchPerformer ?? { query, config in
            if let searchPerformer {
                return try await searchPerformer(query)
            }
            let cacheDirectory = config.xcodeDocumentationCachePath.map {
                URL(fileURLWithPath: $0, isDirectory: true)
            }
            return try await SearchDocsTool(
                api: defaultAppleAPI,
                sosumiAPI: defaultSosumiAPI,
                xcodeDocs: XcodeLocalDocs(
                    fileManager: FileManager.default,
                    searchProvider: SpotlightSearchProvider(),
                    cacheDirectory: cacheDirectory
                )
            ).runDetailed(query: query)
        }
        self.resolvePerformer = configuredResolvePerformer ?? { intent, config in
            let cacheDirectory = config.xcodeDocumentationCachePath.map {
                URL(fileURLWithPath: $0, isDirectory: true)
            }
            let xcodeDocs = XcodeLocalDocs(
                fileManager: FileManager.default,
                searchProvider: SpotlightSearchProvider(),
                cacheDirectory: cacheDirectory
            )
            let diskCache = DiskCache(
                directory: URL(fileURLWithPath: config.cachePath, isDirectory: true),
                fileManager: FileManager.default,
                enableFileLocking: config.enableFileLocking
            )
            let fetchTool = FetchDocTool(
                api: defaultAppleAPI,
                sosumiAPI: defaultSosumiAPI,
                xcodeDocs: xcodeDocs,
                diskCache: diskCache
            )
            let searchTool = SearchDocsTool(
                api: defaultAppleAPI,
                sosumiAPI: defaultSosumiAPI,
                xcodeDocs: xcodeDocs
            )
            return try await ResolveDocsTool(
                fetch: { path in
                    try await fetchTool.runDetailed(path: path)
                },
                search: { query in
                    try await searchTool.run(query: query)
                }
            ).run(intent: Self.mapResolveIntent(intent))
        }
        self.technologiesPerformer = technologiesPerformer ?? {
            try await AppleJSONAPI().fetchTechnologies().map { Technology(name: $0.name, id: $0.url, category: $0.kind) }
        }
        self.usageRecorder = usageRecorder
        try Self.validateVersionCompatibility(adapterVersion: adapterVersion, core: coreVersion)
    }

    public func search(query: String, config: DocumentationConfig) async throws -> [SearchResult] {
        try await searchDetailed(query: query, config: config).results
    }

    public func searchDetailed(query: String, config: DocumentationConfig) async throws -> DocumentationSearchResponse {
        let start = ContinuousClock.now
        do {
            let output = try await searchPerformer(query, config)
            let results = output.results.map {
                SearchResult(
                    id: $0.path,
                    title: $0.title,
                    snippet: $0.abstract,
                    technology: technologyName(from: $0.path),
                    source: mapSource($0.source),
                    sourceKind: $0.sourceKind.rawValue,
                    fetchSupported: $0.fetchSupported,
                    fetchSupportReason: $0.fetchSupportReason,
                    matchScope: $0.matchScope.rawValue,
                    queryAttempt: $0.queryAttempt
                )
            }
            await recordUsageIfConfigured(
                DocumentationUsageLogEntry(
                    operation: "search",
                    caller: config.callerID,
                    status: .success,
                    query: query,
                    localeIdentifier: config.locale.identifier,
                    durationMs: output.instrumentation.totalDurationMs,
                    resultCount: results.count,
                    source: output.instrumentation.finalSource,
                    searchStages: output.instrumentation.stages
                ),
                config: config
            )

            return DocumentationSearchResponse(
                results: results,
                diagnostics: SearchDiagnostics(
                    stages: output.instrumentation.stages.map(Self.mapStageDiagnostic)
                )
            )
        } catch {
            logger.log(level: .error, message: "Adapter search failed", context: ["query": query, "error": error.localizedDescription])
            let mappedError = mapError(error, fallbackID: query)
            await recordUsageIfConfigured(
                DocumentationUsageLogEntry(
                    operation: "search",
                    caller: config.callerID,
                    status: .failure,
                    query: query,
                    localeIdentifier: config.locale.identifier,
                    durationMs: durationInMilliseconds(since: start),
                    resultCount: 0,
                    source: nil,
                    errorCategory: errorCategory(for: mappedError),
                    errorMessage: mappedError.localizedDescription,
                    searchStages: nil
                ),
                config: config
            )
            throw mappedError
        }
    }

    public func resolve(intent: ResolveIntent, config: DocumentationConfig) async throws -> ResolveResult {
        let start = ContinuousClock.now
        do {
            let output = try await resolvePerformer(intent, config)
            let result = Self.mapResolveResult(output)
            await recordUsageIfConfigured(
                DocumentationUsageLogEntry(
                    operation: "resolve",
                    caller: config.callerID,
                    status: .success,
                    query: resolveUsageQuery(from: intent),
                    id: result.canonicalPath,
                    localeIdentifier: config.locale.identifier,
                    durationMs: durationInMilliseconds(since: start),
                    resultCount: result.canonicalPath == nil ? 0 : 1,
                    source: result.evidence?.source
                ),
                config: config
            )
            return result
        } catch {
            let mappedError = mapResolveError(error)
            logger.log(level: .error, message: "Adapter resolve failed", context: ["intent": resolveUsageQuery(from: intent), "error": mappedError.localizedDescription])
            await recordUsageIfConfigured(
                DocumentationUsageLogEntry(
                    operation: "resolve",
                    caller: config.callerID,
                    status: .failure,
                    query: resolveUsageQuery(from: intent),
                    localeIdentifier: config.locale.identifier,
                    durationMs: durationInMilliseconds(since: start),
                    resultCount: 0,
                    source: nil,
                    errorCategory: errorCategory(for: mappedError),
                    errorMessage: mappedError.localizedDescription
                ),
                config: config
            )
            throw mappedError
        }
    }

    public func fetch(id: String, config: DocumentationConfig) async throws -> DocumentationContent {
        let start = ContinuousClock.now
        do {
            let cacheURL = URL(fileURLWithPath: config.cachePath, isDirectory: true)
            let diskCache = DiskCache(
                directory: cacheURL,
                fileManager: FileManager.default,
                enableFileLocking: config.enableFileLocking
            )
            let xcodeCacheDirectory = config.xcodeDocumentationCachePath.map {
                URL(fileURLWithPath: $0, isDirectory: true)
            }
            let output = try await FetchDocTool(
                api: AppleJSONAPI(),
                sosumiAPI: SosumiAPI(),
                xcodeDocs: XcodeLocalDocs(
                    fileManager: FileManager.default,
                    searchProvider: SpotlightSearchProvider(),
                    cacheDirectory: xcodeCacheDirectory
                ),
                diskCache: diskCache
            ).runDetailed(path: id)

            let result = DocumentationContent(
                title: titleFromBody(output, fallback: id),
                body: output.markdown,
                metadata: [
                    "locale": config.locale.identifier,
                    "source": output.source.rawValue
                ],
                url: URLHelpers.webURL(for: id) ?? URL(string: "https://developer.apple.com\(id)")!,
                fetchDiagnostics: output.sourceAttempts.map(Self.mapFetchAttemptDiagnostic)
            )
            await recordUsageIfConfigured(
                DocumentationUsageLogEntry(
                    operation: "fetch",
                    caller: config.callerID,
                    status: .success,
                    id: id,
                    localeIdentifier: config.locale.identifier,
                    durationMs: durationInMilliseconds(since: start),
                    resultCount: 1,
                    source: output.source.rawValue
                ),
                config: config
            )
            return result
        } catch {
            logger.log(level: .error, message: "Adapter fetch failed", context: ["id": id, "error": error.localizedDescription])
            let mappedError = mapError(error, fallbackID: id)
            await recordUsageIfConfigured(
                DocumentationUsageLogEntry(
                    operation: "fetch",
                    caller: config.callerID,
                    status: .failure,
                    id: id,
                    localeIdentifier: config.locale.identifier,
                    durationMs: durationInMilliseconds(since: start),
                    resultCount: 0,
                    source: nil,
                    errorCategory: errorCategory(for: mappedError),
                    errorMessage: mappedError.localizedDescription
                ),
                config: config
            )
            throw mappedError
        }
    }

    public func listTechnologies(config: DocumentationConfig) async throws -> [Technology] {
        let start = ContinuousClock.now
        do {
            let technologies = try await technologiesPerformer()
            let filtered = filterTechnologies(technologies, category: config.technologyCategoryFilter)
            await recordUsageIfConfigured(
                DocumentationUsageLogEntry(
                    operation: "list",
                    caller: config.callerID,
                    status: .success,
                    category: config.technologyCategoryFilter,
                    localeIdentifier: config.locale.identifier,
                    durationMs: durationInMilliseconds(since: start),
                    resultCount: filtered.count,
                    source: filtered.isEmpty ? nil : "apple"
                ),
                config: config
            )
            return filtered
        } catch {
            logger.log(level: .error, message: "Adapter listTechnologies failed", context: ["error": error.localizedDescription])
            let mappedError = mapError(error, fallbackID: "technologies")
            await recordUsageIfConfigured(
                DocumentationUsageLogEntry(
                    operation: "list",
                    caller: config.callerID,
                    status: .failure,
                    category: config.technologyCategoryFilter,
                    localeIdentifier: config.locale.identifier,
                    durationMs: durationInMilliseconds(since: start),
                    resultCount: 0,
                    source: nil,
                    errorCategory: errorCategory(for: mappedError),
                    errorMessage: mappedError.localizedDescription
                ),
                config: config
            )
            throw mappedError
        }
    }

    public func getCoreVersion() -> String {
        coreVersion
    }

    public static func validateVersionCompatibility(adapterVersion: String, core: String) throws {
        guard let adapterSemVer = SemVer(parsing: adapterVersion),
              let coreSemVer = SemVer(parsing: core) else {
            throw DocumentationError.incompatibleVersion(adapter: adapterVersion, core: core)
        }

        guard adapterSemVer.isMajorCompatible(with: coreSemVer) else {
            throw DocumentationError.incompatibleVersion(adapter: adapterVersion, core: core)
        }
    }

    private static func mapStageDiagnostic(_ stage: DocumentationSearchStageTiming) -> SearchStageDiagnostic {
        SearchStageDiagnostic(
            name: stage.name,
            status: stage.status.rawValue,
            durationMs: stage.durationMs,
            resultCount: stage.resultCount,
            reason: stage.reason,
            hint: stage.hint,
            queryAttempt: stage.queryAttempt
        )
    }

    private static func mapFetchAttemptDiagnostic(_ attempt: FetchSourceAttempt) -> FetchAttemptDiagnostic {
        FetchAttemptDiagnostic(
            source: attempt.source.rawValue,
            status: attempt.status.rawValue,
            reason: attempt.reason,
            contentType: attempt.contentType,
            statusCode: attempt.statusCode,
            hint: attempt.hint
        )
    }

    private static func mapResolveIntent(_ intent: ResolveIntent) -> ResolveDocsIntent {
        ResolveDocsIntent(
            framework: intent.framework,
            symbol: intent.symbol,
            type: intent.type,
            member: intent.member,
            memberKind: intent.memberKind,
            sourceFamily: intent.sourceFamily
        )
    }

    private static func mapResolveResult(_ result: ResolveDocsResult) -> ResolveResult {
        ResolveResult(
            canonicalPath: result.canonicalPath,
            confidence: mapResolveConfidence(result.confidence),
            verifiedByFetch: result.verifiedByFetch,
            evidence: result.evidence.map {
                ResolveEvidence(
                    sourceFamily: $0.sourceFamily,
                    source: $0.source.rawValue,
                    path: $0.path,
                    title: $0.title,
                    summary: $0.summary
                )
            },
            candidates: result.candidates.map {
                ResolveCandidate(
                    path: $0.path,
                    title: $0.title,
                    source: mapResolveCandidateSource($0.source),
                    matchQuality: mapResolveMatchQuality($0.matchQuality),
                    verifiedByFetch: $0.verifiedByFetch,
                    confidence: mapResolveConfidence($0.confidence)
                )
            },
            resolveDiagnostics: result.resolveDiagnostics.map {
                ResolveDiagnostic(
                    stage: $0.stage,
                    status: $0.status,
                    reason: $0.reason,
                    hint: $0.hint,
                    pathAttempt: $0.pathAttempt,
                    queryAttempt: $0.queryAttempt
                )
            },
            fetchDiagnostics: (result.fetchDiagnostics ?? []).map(Self.mapFetchAttemptDiagnostic)
        )
    }

    private static func mapResolveConfidence(_ confidence: ResolveDocsConfidence) -> ResolveConfidence {
        switch confidence {
        case .high:
            return .high
        case .medium:
            return .medium
        case .low:
            return .low
        case .unresolved:
            return .unresolved
        }
    }

    private static func mapResolveCandidateSource(_ source: ResolveDocsCandidateSource) -> ResolveCandidateSource {
        switch source {
        case .direct:
            return .direct
        case .searchFallback:
            return .searchFallback
        }
    }

    private static func mapResolveMatchQuality(_ quality: ResolveDocsMatchQuality) -> ResolveMatchQuality {
        switch quality {
        case .exact:
            return .exact
        case .partial:
            return .partial
        case .mismatch:
            return .mismatch
        case .unknown:
            return .unknown
        }
    }

    private func mapResolveError(_ error: Error) -> DocumentationError {
        if let existing = error as? DocumentationError {
            return existing
        }
        if let resolveError = error as? ResolveDocsError {
            switch resolveError {
            case .invalidIntent(let message):
                return .invalidResolveIntent(message: message)
            }
        }
        return mapError(error, fallbackID: "resolve")
    }

    private func mapError(_ error: Error, fallbackID: String) -> DocumentationError {
        if let existing = error as? DocumentationError {
            return existing
        }

        if let idocsError = error as? iDocsError {
            switch idocsError {
            case .invalidURL:
                return .invalidConfiguration(message: "Invalid URL for id: \(fallbackID)")
            case .httpError(let statusCode):
                if statusCode == 401 || statusCode == 403 {
                    return .unauthorized
                }
                if statusCode == 404 {
                    return .notFound(id: fallbackID)
                }
                return .networkError(message: "HTTP status \(statusCode)")
            case .maxRetriesReached:
                return .networkError(message: "Max retries reached")
            case .invalidResponse:
                return .networkError(message: "Invalid response")
            case .emptyResponse:
                return .parsingError(reason: "Empty response")
            case .unsupportedSourceType(let path, let sourceKind, let attempts):
                return .unsupportedSourceType(
                    id: path,
                    sourceKind: sourceKind.rawValue,
                    attempts: attempts.map(Self.mapFetchAttemptDiagnostic)
                )
            case .aggregateFetchFailure(let path, let attempts):
                let summary = attempts
                    .filter { $0.status == .error || $0.status == .unsupported }
                    .map { "\($0.source.rawValue): \($0.reason ?? $0.status.rawValue)" }
                    .joined(separator: "; ")
                return .aggregateFetchFailure(
                    id: path,
                    message: summary.isEmpty ? "Fetch failed for \(path)" : summary,
                    attempts: attempts.map(Self.mapFetchAttemptDiagnostic)
                )
            }
        }

        return .internalError(message: error.localizedDescription)
    }

    private func technologyName(from path: String) -> String {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = trimmed.split(separator: "/")
        if parts.count >= 2 && parts[0] == "documentation" {
            return String(parts[1])
        }
        return "unknown"
    }

    private func resolveUsageQuery(from intent: ResolveIntent) -> String {
        [intent.framework, intent.symbol, intent.type, intent.member]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    private func titleFromBody(_ content: FetchDocResult, fallback: String) -> String {
        for line in content.markdown.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                return trimmed.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return fallback
    }

    private func mapSource(_ source: DataSource) -> RetrievalSource {
        switch source {
        case .cache:
            return .cache
        case .local:
            return .local
        case .apple:
            return .apple
        case .help:
            return .help
        case .sosumi:
            return .sosumi
        case .unsupported:
            return .unsupported
        }
    }

    private func recordUsageIfConfigured(_ entry: DocumentationUsageLogEntry, config: DocumentationConfig) async {
        guard let usageLogPath = config.usageLogPath, !usageLogPath.isEmpty else { return }
        do {
            try await usageRecorder.record(entry, to: usageLogPath)
        } catch {
            logger.log(
                level: .warning,
                message: "Failed to write usage log",
                context: ["path": usageLogPath, "error": error.localizedDescription]
            )
        }
    }

    private func durationInMilliseconds(since start: ContinuousClock.Instant) -> Double {
        let duration = start.duration(to: ContinuousClock.now)
        return Double(duration.components.seconds) * 1_000
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000
    }

    private func filterTechnologies(
        _ technologies: [Technology],
        category: String?
    ) -> [Technology] {
        guard let category = category?.trimmingCharacters(in: .whitespacesAndNewlines),
              !category.isEmpty else {
            return technologies
        }

        return technologies.filter { technology in
            technology.category?.localizedCaseInsensitiveContains(category) == true
        }
    }

    private func errorCategory(for error: DocumentationError) -> String {
        switch error {
        case .notFound:
            return "NOT_FOUND"
        case .networkError:
            return "NETWORK"
        case .parsingError:
            return "PARSING"
        case .unauthorized:
            return "UNAUTHORIZED"
        case .invalidConfiguration, .invalidResolveIntent:
            return "CONFIG"
        case .incompatibleVersion:
            return "VERSION_MISMATCH"
        case .internalError:
            return "INTERNAL"
        case .unsupportedSourceType:
            return "CONFIG"
        case .aggregateFetchFailure:
            return "NETWORK"
        }
    }
}
