import Foundation
import Logging

public struct SearchDocsTool {
    private let logger = Logger(label: "com.snow.idocs-search-tool")
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

        // 0. Try Memory Cache
        let cacheStart = ContinuousClock.now
        if let cached = await memoryCache.get(query) {
            let mapped = cached.map { result in
                SearchResult(
                    title: result.title,
                    abstract: result.abstract,
                    path: result.path,
                    kind: result.kind,
                    source: .cache,
                    relevance: result.relevance
                )
            }
            stages.append(
                DocumentationSearchStageTiming(
                    name: "cache",
                    status: .hit,
                    durationMs: durationInMilliseconds(since: cacheStart),
                    resultCount: mapped.count
                )
            )
            logger.info("Memory cache hit for: \(query)")
            return buildOutput(
                results: mapped,
                stages: stages,
                totalStart: totalStart
            )
        }
        stages.append(
            DocumentationSearchStageTiming(
                name: "cache",
                status: .miss,
                durationMs: durationInMilliseconds(since: cacheStart),
                resultCount: 0
            )
        )
        
        // 1. Try Local Xcode
        let localStart = ContinuousClock.now
        do {
            let localResults = try await xcodeDocs.search(query: query)
            if !localResults.isEmpty {
                stages.append(
                    DocumentationSearchStageTiming(
                        name: "local",
                        status: .hit,
                        durationMs: durationInMilliseconds(since: localStart),
                        resultCount: localResults.count
                    )
                )
                logger.info("Found \(localResults.count) matches in local Xcode documentation.")
                await memoryCache.set(query, value: localResults)
                return buildOutput(
                    results: localResults,
                    stages: stages,
                    totalStart: totalStart
                )
            }
            stages.append(
                DocumentationSearchStageTiming(
                    name: "local",
                    status: .miss,
                    durationMs: durationInMilliseconds(since: localStart),
                    resultCount: 0
                )
            )
        } catch {
            stages.append(
                DocumentationSearchStageTiming(
                    name: "local",
                    status: .error,
                    durationMs: durationInMilliseconds(since: localStart),
                    resultCount: 0
                )
            )
            logger.warning("Local Xcode search failed: \(error.localizedDescription)")
        }
        
        // 2. Try Apple Remote API
        let appleStart = ContinuousClock.now
        do {
            logger.info("Falling back to Apple remote API search.")
            let appleAPI = self.appleAPI
            let appleResults = try await withRemoteSearchTimeout(stage: "apple") {
                try await appleAPI.search(query: query)
            }
            if !appleResults.isEmpty {
                stages.append(
                    DocumentationSearchStageTiming(
                        name: "apple",
                        status: .hit,
                        durationMs: durationInMilliseconds(since: appleStart),
                        resultCount: appleResults.count
                    )
                )
                await memoryCache.set(query, value: appleResults)
                return buildOutput(
                    results: appleResults,
                    stages: stages,
                    totalStart: totalStart
                )
            }
            stages.append(
                DocumentationSearchStageTiming(
                    name: "apple",
                    status: .miss,
                    durationMs: durationInMilliseconds(since: appleStart),
                    resultCount: 0
                )
            )
            logger.info("Apple remote returned no results, trying sosumi fallback.")
        } catch {
            stages.append(
                DocumentationSearchStageTiming(
                    name: "apple",
                    status: .error,
                    durationMs: durationInMilliseconds(since: appleStart),
                    resultCount: 0
                )
            )
            logger.warning("Apple remote search failed: \(error.localizedDescription). Trying sosumi fallback.")
        }

        // 3. Try sosumi fallback
        let sosumiStart = ContinuousClock.now
        do {
            let sosumiAPI = self.sosumiAPI
            let sosumiResults = try await withRemoteSearchTimeout(stage: "sosumi") {
                try await sosumiAPI.search(query: query)
            }
            stages.append(
                DocumentationSearchStageTiming(
                    name: "sosumi",
                    status: sosumiResults.isEmpty ? .miss : .hit,
                    durationMs: durationInMilliseconds(since: sosumiStart),
                    resultCount: sosumiResults.count
                )
            )
            await memoryCache.set(query, value: sosumiResults)
            return buildOutput(
                results: sosumiResults,
                stages: stages,
                totalStart: totalStart
            )
        } catch {
            stages.append(
                DocumentationSearchStageTiming(
                    name: "sosumi",
                    status: .error,
                    durationMs: durationInMilliseconds(since: sosumiStart),
                    resultCount: 0
                )
            )
            logger.warning("Sosumi search failed: \(error.localizedDescription). Returning empty results.")
            return buildOutput(
                results: [],
                stages: stages,
                totalStart: totalStart
            )
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
                totalDurationMs: durationInMilliseconds(since: totalStart),
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

    private func durationInMilliseconds(since start: ContinuousClock.Instant) -> Double {
        let duration = start.duration(to: ContinuousClock.now)
        return Double(duration.components.seconds) * 1_000
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000
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
