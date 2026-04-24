import Foundation
import iDocsKit

public struct DefaultDocumentationAdapter: DocumentationService {
    private let adapterVersion: String
    private let logger: any DocumentationLogger
    private let searchPerformer: @Sendable (String) async throws -> SearchDocsRunOutput
    private let technologiesPerformer: @Sendable () async throws -> [Technology]
    private let usageRecorder: DocumentationUsageRecorder

    public init(
        adapterVersion: String = "1.0.0",
        logger: any DocumentationLogger = NoopDocumentationLogger(),
        searchPerformer: (@Sendable (String) async throws -> SearchDocsRunOutput)? = nil,
        technologiesPerformer: (@Sendable () async throws -> [Technology])? = nil,
        usageRecorder: DocumentationUsageRecorder = DocumentationUsageRecorder()
    ) throws {
        self.adapterVersion = adapterVersion
        self.logger = logger
        self.searchPerformer = searchPerformer ?? { query in
            try await SearchDocsTool(
                api: AppleJSONAPI(),
                sosumiAPI: SosumiAPI(),
                xcodeDocs: XcodeLocalDocs(fileManager: FileManager.default, searchProvider: SpotlightSearchProvider())
            ).runDetailed(query: query)
        }
        self.technologiesPerformer = technologiesPerformer ?? {
            try await AppleJSONAPI().fetchTechnologies().map { Technology(name: $0.name, id: $0.url, category: $0.kind) }
        }
        self.usageRecorder = usageRecorder
        try Self.validateVersionCompatibility(adapterVersion: adapterVersion, core: coreVersion)
    }

    public func search(query: String, config: DocumentationConfig) async throws -> [SearchResult] {
        let start = ContinuousClock.now
        do {
            let output = try await searchPerformer(query)
            let results = output.results.map {
                SearchResult(
                    id: $0.path,
                    title: $0.title,
                    snippet: $0.abstract,
                    technology: technologyName(from: $0.path),
                    source: mapSource($0.source)
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

            return results
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

    public func fetch(id: String, config: DocumentationConfig) async throws -> DocumentationContent {
        let start = ContinuousClock.now
        do {
            let cacheURL = URL(fileURLWithPath: config.cachePath, isDirectory: true)
            let diskCache = DiskCache(
                directory: cacheURL,
                fileManager: FileManager.default,
                enableFileLocking: config.enableFileLocking
            )
            let output = try await FetchDocTool(
                api: AppleJSONAPI(),
                sosumiAPI: SosumiAPI(),
                xcodeDocs: XcodeLocalDocs(fileManager: FileManager.default, searchProvider: SpotlightSearchProvider()),
                diskCache: diskCache
            ).runDetailed(path: id)

            let result = DocumentationContent(
                title: titleFromBody(output, fallback: id),
                body: output.markdown,
                metadata: [
                    "locale": config.locale.identifier,
                    "source": output.source.rawValue
                ],
                url: URLHelpers.webURL(for: id) ?? URL(string: "https://developer.apple.com\(id)")!
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
        case .sosumi:
            return .sosumi
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
        case .invalidConfiguration:
            return "CONFIG"
        case .incompatibleVersion:
            return "VERSION_MISMATCH"
        case .internalError:
            return "INTERNAL"
        }
    }
}
