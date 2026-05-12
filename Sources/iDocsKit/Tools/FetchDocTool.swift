import Foundation
import Logging

public struct FetchDocTool {
    private let logger = Logger(label: "com.snow.idocs-fetch-tool")
    private let appleAPI: AppleJSONAPI
    private let sosumiAPI: SosumiAPI
    private let helpAPI: AppleHelpAPI
    private let xcodeDocs: XcodeLocalDocs
    private let renderer = DocCRenderer()
    private let diskCache: DiskCache
    
    public init(api: AppleJSONAPI = AppleJSONAPI(),
                sosumiAPI: SosumiAPI = SosumiAPI(),
                helpAPI: AppleHelpAPI = AppleHelpAPI(),
                xcodeDocs: XcodeLocalDocs = XcodeLocalDocs(),
                diskCache: DiskCache = DiskCache(name: "docs")) {
        self.appleAPI = api
        self.sosumiAPI = sosumiAPI
        self.helpAPI = helpAPI
        self.xcodeDocs = xcodeDocs
        self.diskCache = diskCache
    }
    
    public func run(path: String) async throws -> String {
        try await runDetailed(path: path).markdown
    }

    public func runDetailed(path: String) async throws -> FetchDocResult {
        logger.info("Fetching Apple documentation for path: \(path)")
        var attempts: [FetchSourceAttempt] = []
        
        // 1. Try Disk Cache
        if let cachedData = try? await diskCache.get(path) {
            if let content = try? JSONDecoder().decode(DocCContent.self, from: cachedData) {
                logger.info("Disk cache hit for: \(path)")
                attempts.append(FetchSourceAttempt(source: .cache, status: .hit))
                return FetchDocResult(markdown: try renderer.render(content), source: .cache, sourceAttempts: attempts)
            }
            if let markdown = String(data: cachedData, encoding: .utf8), !markdown.isEmpty {
                logger.info("Disk cache markdown hit for: \(path)")
                attempts.append(FetchSourceAttempt(source: .cache, status: .hit))
                return FetchDocResult(markdown: markdown, source: .cache, sourceAttempts: attempts)
            }
            try? await diskCache.remove(path)
            attempts.append(FetchSourceAttempt(source: .cache, status: .error, reason: "corrupt_cache_entry"))
        } else {
            attempts.append(FetchSourceAttempt(source: .cache, status: .miss, reason: "cache_miss"))
        }
        
        // 2. Try Local Xcode
        do {
            if let localContent = try await xcodeDocs.fetchDoc(path: path) {
                logger.info("Local Xcode documentation hit for: \(path)")
                if let data = try? JSONEncoder().encode(localContent) {
                    try? await diskCache.set(path, value: data, ttl: 3600 * 24)
                }
                attempts.append(FetchSourceAttempt(source: .local, status: .hit))
                return FetchDocResult(markdown: try renderer.render(localContent), source: .local, sourceAttempts: attempts)
            }
            attempts.append(FetchSourceAttempt(source: .local, status: .miss, reason: "local_no_results"))
        } catch {
            attempts.append(FetchSourceAttempt(source: .local, status: .error, reason: localFetchFailureReason(for: error)))
        }

        let sourceKind = AppleSourceKind(path: path)
        if sourceKind == .help {
            do {
                let markdown = try await helpAPI.fetchMarkdown(path: path)
                if let data = markdown.data(using: .utf8) {
                    try? await diskCache.set(path, value: data, ttl: 3600 * 12)
                }
                attempts.append(FetchSourceAttempt(source: .help, status: .hit))
                return FetchDocResult(markdown: markdown, source: .help, sourceAttempts: attempts)
            } catch {
                attempts.append(FetchSourceAttempt(source: .help, status: .error, reason: fetchFailureReason(for: error), statusCode: httpStatusCode(from: error)))
            }
        }

        if !sourceKind.fetchSupportedByIDocs {
            attempts.append(
                FetchSourceAttempt(
                    source: .unsupported,
                    status: .unsupported,
                    reason: "unsupported_source_type",
                    hint: "This Apple page family is real but not supported by idocs fetch; use deliberate web fallback if evidence is required."
                )
            )
            throw iDocsError.unsupportedSourceType(path: path, sourceKind: sourceKind, attempts: attempts)
        }
        
        // 3. Try Apple Remote API
        if sourceKind != .help {
            do {
                let content = try await appleAPI.fetchDoc(path: path)
                if let data = try? JSONEncoder().encode(content) {
                    try? await diskCache.set(path, value: data, ttl: 3600 * 24)
                }
                attempts.append(FetchSourceAttempt(source: .apple, status: .hit))
                return FetchDocResult(markdown: try renderer.render(content), source: .apple, sourceAttempts: attempts)
            } catch {
                attempts.append(FetchSourceAttempt(source: .apple, status: .error, reason: fetchFailureReason(for: error), statusCode: httpStatusCode(from: error)))
                logger.warning("Apple remote fetch failed: \(error.localizedDescription). Trying sosumi fallback.")
            }
        }

        // 4. Try sosumi remote fallback (already rendered markdown)
        do {
            let markdown = try await sosumiAPI.fetchMarkdown(path: path)
            if let data = markdown.data(using: .utf8) {
                try? await diskCache.set(path, value: data, ttl: 3600 * 12)
            }
            attempts.append(FetchSourceAttempt(source: .sosumi, status: .hit))
            return FetchDocResult(markdown: markdown, source: .sosumi, sourceAttempts: attempts)
        } catch {
            attempts.append(FetchSourceAttempt(source: .sosumi, status: .error, reason: fetchFailureReason(for: error), statusCode: httpStatusCode(from: error)))
            throw iDocsError.aggregateFetchFailure(path: path, attempts: attempts)
        }
    }

    private func fetchFailureReason(for error: Error) -> String {
        if error is DecodingError {
            return "remote_decode_failed"
        }
        if let idocsError = error as? iDocsError {
            return idocsError.reason
        }
        if error is URLError {
            return "remote_network_failure"
        }
        return "fetch_failed"
    }

    private func localFetchFailureReason(for error: Error) -> String {
        if error is DecodingError {
            return "local_decode_failed"
        }
        if let idocsError = error as? iDocsError {
            return idocsError.reason
        }
        return "local_fetch_failed"
    }

    private func httpStatusCode(from error: Error) -> Int? {
        guard let idocsError = error as? iDocsError else { return nil }
        if case .httpError(let statusCode) = idocsError {
            return statusCode
        }
        return nil
    }
}

public struct FetchDocResult: Sendable {
    public let markdown: String
    public let source: DataSource
    public let sourceAttempts: [FetchSourceAttempt]

    public init(markdown: String, source: DataSource, sourceAttempts: [FetchSourceAttempt] = []) {
        self.markdown = markdown
        self.source = source
        self.sourceAttempts = sourceAttempts
    }
}
