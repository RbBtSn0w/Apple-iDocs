import Foundation
import iDocsKit

public struct DefaultDocumentationAdapter: DocumentationService {
    private let adapterVersion: String
    private let logger: any DocumentationLogger

    public init(
        adapterVersion: String = "1.0.0",
        logger: any DocumentationLogger = NoopDocumentationLogger()
    ) throws {
        self.adapterVersion = adapterVersion
        self.logger = logger
        try Self.validateVersionCompatibility(adapterVersion: adapterVersion, core: coreVersion)
    }

    public func search(query: String, config: DocumentationConfig) async throws -> [SearchResult] {
        do {
            let results = try await SearchDocsTool(
                api: AppleJSONAPI(),
                sosumiAPI: SosumiAPI(),
                xcodeDocs: XcodeLocalDocs(fileManager: FileManager.default, searchProvider: SpotlightSearchProvider())
            ).run(query: query)

            return results.map {
                SearchResult(
                    id: $0.path,
                    title: $0.title,
                    snippet: $0.abstract,
                    technology: technologyName(from: $0.path),
                    source: mapSource($0.source)
                )
            }
        } catch {
            logger.log(level: .error, message: "Adapter search failed", context: ["query": query, "error": error.localizedDescription])
            throw mapError(error, fallbackID: query)
        }
    }

    public func fetch(id: String, config: DocumentationConfig) async throws -> DocumentationContent {
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

            return DocumentationContent(
                title: titleFromBody(output, fallback: id),
                body: output.markdown,
                metadata: [
                    "locale": config.locale.identifier,
                    "source": output.source.rawValue
                ],
                url: URLHelpers.webURL(for: id) ?? URL(string: "https://developer.apple.com\(id)")!
            )
        } catch {
            logger.log(level: .error, message: "Adapter fetch failed", context: ["id": id, "error": error.localizedDescription])
            throw mapError(error, fallbackID: id)
        }
    }

    public func listTechnologies(config: DocumentationConfig) async throws -> [Technology] {
        do {
            let technologies = try await AppleJSONAPI().fetchTechnologies()
            return technologies.map { Technology(name: $0.name, id: $0.url, category: $0.kind) }
        } catch {
            logger.log(level: .error, message: "Adapter listTechnologies failed", context: ["error": error.localizedDescription])
            throw mapError(error, fallbackID: "technologies")
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
}
