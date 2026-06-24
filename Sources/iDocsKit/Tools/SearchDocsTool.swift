import Foundation
import Logging

public struct SearchDocsTool {
    private let logger = Logger(label: "com.snow.idocs-search-tool")
    private static let keywordFallbackStopWords: Set<String> = [
        "how", "do", "does", "can", "i", "we", "you", "a", "an", "the",
        "to", "in", "on", "for", "with", "and", "or", "of", "my", "your",
        "build", "builds"
    ]
    private let appleAPI: AppleJSONAPI
    private let sosumiAPI: SosumiAPI
    private let xcodeDocs: XcodeLocalDocs
    private let memoryCache: MemoryCache<String, [SearchResult]>
    private let remoteSearchTimeoutSeconds: TimeInterval
    
    public init(api: AppleJSONAPI = AppleJSONAPI(),
                sosumiAPI: SosumiAPI = SosumiAPI(),
                xcodeDocs: XcodeLocalDocs = XcodeLocalDocs(),
                memoryCache: MemoryCache<String, [SearchResult]> = MemoryCache<String, [SearchResult]>(capacity: 50),
                remoteSearchTimeoutSeconds: TimeInterval = 5.0) {
        self.appleAPI = api
        self.sosumiAPI = sosumiAPI
        self.xcodeDocs = xcodeDocs
        self.memoryCache = memoryCache
        self.remoteSearchTimeoutSeconds = remoteSearchTimeoutSeconds
    }
    
    public func run(query: String) async throws -> [SearchResult] {
        try await runDetailed(query: query).results
    }

    public func runDetailed(query: String) async throws -> SearchDocsRunOutput {
        logger.info("Searching Apple documentation for: \(query)")
        let totalStart = ContinuousClock.now
        var stages: [DocumentationSearchStageTiming] = []

        let cacheStage = await searchCache(query: query)
        stages.append(cacheStage.stage)
        if let cached = cacheStage.results {
            return buildOutput(
                results: cached,
                stages: stages,
                totalStart: totalStart
            )
        }

        let localStage = await searchLocal(query: query)
        stages.append(localStage.stage)
        if let local = localStage.results {
            return buildOutput(
                results: local,
                stages: stages,
                totalStart: totalStart
            )
        }

        let appleStage = await searchApple(query: query, localModuleFallbackResults: localStage.moduleFallbackResults)
        stages.append(contentsOf: appleStage.stages)
        if let apple = appleStage.results {
            return buildOutput(
                results: apple,
                stages: stages,
                totalStart: totalStart
            )
        }

        let sosumiStage = await searchSosumi(query: query, localModuleFallbackResults: localStage.moduleFallbackResults)
        stages.append(contentsOf: sosumiStage.stages)
        return buildOutput(
            results: sosumiStage.results,
            stages: stages,
            totalStart: totalStart
        )
    }

    private func searchCache(query: String) async -> (results: [SearchResult]?, stage: DocumentationSearchStageTiming) {
        let cacheStart = ContinuousClock.now
        guard let cached = await memoryCache.get(query) else {
            return (
                nil,
                DocumentationSearchStageTiming(
                    name: "cache",
                    status: .miss,
                    durationMs: cacheStart.millisecondsElapsed(),
                    resultCount: 0,
                    reason: "cache_miss",
                    queryAttempt: query
                )
            )
        }

        let mapped = cached.map { result in
            SearchResult(
                title: result.title,
                abstract: result.abstract,
                path: result.path,
                kind: result.kind,
                source: .cache,
                relevance: result.relevance,
                sourceKind: result.sourceKind,
                fetchSupported: result.fetchSupported,
                fetchSupportReason: result.fetchSupportReason,
                matchScope: result.matchScope,
                queryAttempt: result.queryAttempt ?? query
            )
        }
        logger.info("Memory cache hit for: \(query)")
        return (
            mapped,
            DocumentationSearchStageTiming(
                name: "cache",
                status: .hit,
                durationMs: cacheStart.millisecondsElapsed(),
                resultCount: mapped.count,
                queryAttempt: query
            )
        )
    }

    private func searchLocal(query: String) async -> (
        results: [SearchResult]?,
        moduleFallbackResults: [SearchResult],
        stage: DocumentationSearchStageTiming
    ) {
        let localStart = ContinuousClock.now
        do {
            let localResults = try await xcodeDocs.search(query: query)
            if localResults.isEmpty {
                let localUnavailable = !xcodeDocs.isDocumentationCacheAvailable()
                return (
                    nil,
                    [],
                    DocumentationSearchStageTiming(
                        name: "local",
                        status: .miss,
                        durationMs: localStart.millisecondsElapsed(),
                        resultCount: 0,
                        reason: localUnavailable ? "local_docs_unavailable" : "local_no_results",
                        hint: localUnavailable
                            ? "Xcode local documentation is unavailable; this run is remote-only until the local DocumentationCache is restored."
                            : "Local Xcode documentation did not return a match; remote Apple and sosumi fallbacks will be attempted.",
                        queryAttempt: query
                    )
                )
            }

            let mapped = annotateResults(localResults, queryAttempt: query)
            let shouldContinueRemote = shouldContinueRemoteSearch(afterLocalResults: mapped, originalQuery: query)
            logger.info("Found \(mapped.count) matches in local Xcode documentation.")
            if !shouldContinueRemote {
                await memoryCache.set(query, value: mapped)
            }

            return (
                shouldContinueRemote ? nil : mapped,
                shouldContinueRemote ? mapped : [],
                DocumentationSearchStageTiming(
                    name: "local",
                    status: .hit,
                    durationMs: localStart.millisecondsElapsed(),
                    resultCount: mapped.count,
                    reason: shouldContinueRemote ? "local_module_fallback" : nil,
                    hint: shouldContinueRemote
                        ? "Only module-level local results were found; remote Apple and sosumi fallbacks will be attempted for symbol-level evidence."
                        : nil,
                    queryAttempt: query
                )
            )
        } catch {
            logger.warning("Local Xcode search failed: \(error.localizedDescription)")
            return (
                nil,
                [],
                DocumentationSearchStageTiming(
                    name: "local",
                    status: .error,
                    durationMs: localStart.millisecondsElapsed(),
                    resultCount: 0,
                    reason: "local_error",
                    hint: "Local Xcode documentation search failed; remote Apple and sosumi fallbacks will be attempted.",
                    queryAttempt: query
                )
            )
        }
    }

    /// Annotated and ranked results for a single remote search attempt, plus the
    /// stage timing that describes it. Returned by ``runRemoteStage`` so the
    /// provider-specific orchestration only has to decide how to route the outcome.
    private struct RemoteStageOutcome {
        let mapped: [SearchResult]
        let ranked: [SearchResult]
        let stage: DocumentationSearchStageTiming
    }

    /// Executes one remote provider search under the shared timeout, then performs
    /// the annotate → rank → stage-timing pipeline that Apple and sosumi both use.
    /// `rankingQuery` drives relevance scoring while `attemptQuery` labels the
    /// annotation and stage; they differ only for the sosumi keyword fallback,
    /// which ranks the recovered keyword results against the original query.
    private func runRemoteStage(
        name: String,
        rankingQuery: String,
        attemptQuery: String,
        start: ContinuousClock.Instant,
        provider: @escaping @Sendable () async throws -> [SearchResult]
    ) async throws -> RemoteStageOutcome {
        let rawResults = try await withRemoteSearchTimeout(stage: name, operation: provider)
        let mapped = annotateResults(rawResults, queryAttempt: attemptQuery)
        let ranked = mapped.isEmpty ? [] : SearchResultRanker(query: rankingQuery).rankedRemoteResults(mapped)
        let stage = DocumentationSearchStageTiming(
            name: name,
            status: ranked.isEmpty ? .miss : .hit,
            durationMs: start.millisecondsElapsed(),
            resultCount: ranked.count,
            reason: mapped.isEmpty ? "remote_no_results" : (ranked.isEmpty ? "low_confidence_remote_results" : nil),
            hint: mapped.isEmpty ? searchQualityMissHint(stage: name) : (ranked.isEmpty ? lowConfidenceRemoteHint(stage: name) : nil),
            queryAttempt: attemptQuery
        )
        return RemoteStageOutcome(mapped: mapped, ranked: ranked, stage: stage)
    }

    private func remoteErrorStage(
        name: String,
        start: ContinuousClock.Instant,
        error: Error,
        query: String
    ) -> DocumentationSearchStageTiming {
        DocumentationSearchStageTiming(
            name: name,
            status: .error,
            durationMs: start.millisecondsElapsed(),
            resultCount: 0,
            reason: remoteErrorReason(for: error),
            hint: remoteErrorHint(for: error),
            queryAttempt: query
        )
    }

    private func searchApple(query: String, localModuleFallbackResults: [SearchResult]) async -> (
        results: [SearchResult]?,
        stages: [DocumentationSearchStageTiming]
    ) {
        let appleStart = ContinuousClock.now
        do {
            logger.info("Falling back to Apple remote API search.")
            let appleAPI = self.appleAPI
            let outcome = try await runRemoteStage(
                name: "apple",
                rankingQuery: query,
                attemptQuery: query,
                start: appleStart
            ) {
                try await appleAPI.search(query: query)
            }
            if outcome.mapped.isEmpty {
                logger.info("Apple remote returned no results.")
                if query.isOpaqueMissQuery {
                    let sosumiSkippedStage = DocumentationSearchStageTiming(
                        name: "sosumi",
                        status: .skipped,
                        durationMs: 0,
                        resultCount: 0,
                        reason: "opaque_miss_query",
                        hint: "Skipping broad sosumi fallback for an opaque miss query to avoid noisy unrelated candidates.",
                        queryAttempt: query
                    )
                    return (localModuleFallbackResults, [outcome.stage, sosumiSkippedStage])
                }
                logger.info("Trying sosumi fallback.")
                return (nil, [outcome.stage])
            }

            if !outcome.ranked.isEmpty {
                await memoryCache.set(query, value: outcome.ranked)
                return (outcome.ranked, [outcome.stage])
            }
            logger.info("Apple remote returned only low-confidence results, trying sosumi fallback.")
            return (nil, [outcome.stage])
        } catch {
            logger.warning("Apple remote search failed: \(error.localizedDescription). Trying sosumi fallback.")
            return (nil, [remoteErrorStage(name: "apple", start: appleStart, error: error, query: query)])
        }
    }

    private func searchSosumi(query: String, localModuleFallbackResults: [SearchResult]) async -> (
        results: [SearchResult],
        stages: [DocumentationSearchStageTiming]
    ) {
        let sosumiStart = ContinuousClock.now
        do {
            let sosumiAPI = self.sosumiAPI
            let outcome = try await runRemoteStage(
                name: "sosumi",
                rankingQuery: query,
                attemptQuery: query,
                start: sosumiStart
            ) {
                try await sosumiAPI.search(query: query)
            }
            if !outcome.ranked.isEmpty {
                await memoryCache.set(query, value: outcome.ranked)
                return (outcome.ranked, [outcome.stage])
            }

            if let fallbackQuery = keywordFallbackQuery(for: query), fallbackQuery != query {
                let fallbackStart = ContinuousClock.now
                let fallbackOutcome = try await runRemoteStage(
                    name: "sosumi",
                    rankingQuery: query,
                    attemptQuery: fallbackQuery,
                    start: fallbackStart
                ) {
                    try await sosumiAPI.search(query: fallbackQuery)
                }
                if !fallbackOutcome.ranked.isEmpty {
                    await memoryCache.set(query, value: fallbackOutcome.ranked)
                    return (fallbackOutcome.ranked, [outcome.stage, fallbackOutcome.stage])
                }

                if !localModuleFallbackResults.isEmpty {
                    return (localModuleFallbackResults, [outcome.stage, fallbackOutcome.stage])
                }

                return (fallbackOutcome.ranked, [outcome.stage, fallbackOutcome.stage])
            }

            if !localModuleFallbackResults.isEmpty {
                return (localModuleFallbackResults, [outcome.stage])
            }

            return (outcome.ranked, [outcome.stage])
        } catch {
            logger.warning("Sosumi search failed: \(error.localizedDescription). Returning empty results.")
            let stage = remoteErrorStage(name: "sosumi", start: sosumiStart, error: error, query: query)
            if !localModuleFallbackResults.isEmpty {
                return (localModuleFallbackResults, [stage])
            }
            return ([], [stage])
        }
    }

    private func shouldContinueRemoteSearch(afterLocalResults results: [SearchResult], originalQuery: String) -> Bool {
        guard originalQuery.contains(where: \.isWhitespace) else { return false }
        guard !results.isEmpty else { return false }
        return results.allSatisfy { result in
            result.source == .local
                && result.matchScope == .module
        }
    }

    private func buildOutput(
        results: [SearchResult],
        stages: [DocumentationSearchStageTiming],
        totalStart: ContinuousClock.Instant
    ) -> SearchDocsRunOutput {
        SearchDocsRunOutput(
            results: results,
            instrumentation: DocumentationSearchInstrumentation(
                totalDurationMs: totalStart.millisecondsElapsed(),
                finalSource: primarySource(from: results),
                stages: stages
            )
        )
    }

    private func primarySource(from results: [SearchResult]) -> String? {
        let sources = Set(results.map(\.source.rawValue))
        guard !sources.isEmpty else { return nil }
        if sources.count == 1 {
            return sources.first
        }
        return "mixed"
    }

    private func annotateResults(_ results: [SearchResult], queryAttempt: String) -> [SearchResult] {
        results.map { result in
            SearchResult(
                title: result.title,
                abstract: result.abstract,
                path: result.path,
                kind: result.kind,
                source: result.source,
                relevance: result.relevance,
                sourceKind: result.sourceKind,
                fetchSupported: result.fetchSupported,
                fetchSupportReason: result.fetchSupportReason,
                matchScope: result.matchScope,
                queryAttempt: result.queryAttempt ?? queryAttempt
            )
        }
    }

    private func keywordFallbackQuery(for query: String) -> String? {
        let tokens = query.split { !$0.isLetter && !$0.isNumber }
        let keywords = tokens.filter { token in
            let lower = token.lowercased()
            return (token.count >= 4 || lower == "app") && !Self.keywordFallbackStopWords.contains(lower)
        }
        guard keywords.count >= 3 else { return nil }
        return keywords.prefix(7).joined(separator: " ")
    }

    private func searchQualityMissHint(stage: String) -> String {
        "Remote \(stage) search reached the service but returned no matching results. Try an exact API or HIG title, or report a search-quality miss if the page exists on developer.apple.com."
    }

    private func lowConfidenceRemoteHint(stage: String) -> String {
        "Remote \(stage) returned candidates, but none matched the query intent strongly enough to treat as a documentation hit."
    }

    private func remoteErrorReason(for error: Error) -> String {
        if error is RemoteSearchTimeoutError {
            return "remote_timeout"
        }

        let nsError = error as NSError
        let message = error.localizedDescription.lowercased()
        if nsError.domain == NSPOSIXErrorDomain && nsError.code == 1
            || message.contains("operation not permitted")
            || message.contains("not permitted")
            || message.contains("permission") {
            return "remote_permission_denied"
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .dnsLookupFailed,
                 .internationalRoamingOff,
                 .dataNotAllowed,
                 .secureConnectionFailed:
                return "remote_network_failure"
            case .timedOut:
                return "remote_timeout"
            default:
                break
            }
        }

        if let idocsError = error as? iDocsError {
            switch idocsError {
            case .httpError(let statusCode) where statusCode == 401 || statusCode == 403:
                return "remote_permission_denied"
            case .httpError:
                return "remote_http_error"
            case .maxRetriesReached:
                return "remote_network_failure"
            case .invalidURL:
                return "remote_invalid_url"
            case .invalidResponse:
                return "remote_invalid_response"
            case .emptyResponse:
                return "remote_empty_body"
            case .unsupportedSourceType, .aggregateFetchFailure:
                return idocsError.reason
            }
        }

        return "remote_error"
    }

    private func remoteErrorHint(for error: Error) -> String {
        switch remoteErrorReason(for: error) {
        case "remote_permission_denied":
            return "Retry with network permission enabled; this does not prove the documentation page is missing."
        case "remote_network_failure":
            return "Retry when network access is available; this does not prove the documentation page is missing."
        case "remote_timeout":
            return "Retry with a longer timeout or working network before treating this as a documentation miss."
        case "remote_http_error":
            return "The remote documentation service returned an HTTP error; retry or inspect upstream status before treating this as a documentation miss."
        default:
            return "Inspect the remote error and retry before treating this as a documentation miss."
        }
    }

    private func withRemoteSearchTimeout<T: Sendable>(
        stage: String,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let timeoutSeconds = remoteSearchTimeoutSeconds
        guard timeoutSeconds > 0 else {
            return try await operation()
        }

        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                let nanoseconds = UInt64(timeoutSeconds * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
                throw RemoteSearchTimeoutError(stage: stage, seconds: timeoutSeconds)
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

private struct RemoteSearchTimeoutError: LocalizedError {
    let stage: String
    let seconds: TimeInterval

    var errorDescription: String? {
        "Remote \(stage) search timed out after \(String(format: "%.1f", seconds))s"
    }
}
