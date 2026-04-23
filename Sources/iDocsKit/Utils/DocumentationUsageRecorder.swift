import Foundation

public enum DocumentationUsageStatus: String, Codable, Sendable {
    case success
    case failure
}

public enum DocumentationSearchStageStatus: String, Codable, Sendable, Equatable {
    case hit
    case miss
    case error
    case skipped
}

public struct DocumentationSearchStageTiming: Codable, Sendable, Equatable {
    public let name: String
    public let status: DocumentationSearchStageStatus
    public let durationMs: Double
    public let resultCount: Int

    enum CodingKeys: String, CodingKey {
        case name
        case status
        case durationMs = "duration_ms"
        case resultCount = "result_count"
    }

    public init(name: String, status: DocumentationSearchStageStatus, durationMs: Double, resultCount: Int) {
        self.name = name
        self.status = status
        self.durationMs = durationMs
        self.resultCount = resultCount
    }
}

public struct DocumentationSearchInstrumentation: Sendable {
    public let totalDurationMs: Double
    public let finalSource: String?
    public let stages: [DocumentationSearchStageTiming]

    public init(totalDurationMs: Double, finalSource: String?, stages: [DocumentationSearchStageTiming]) {
        self.totalDurationMs = totalDurationMs
        self.finalSource = finalSource
        self.stages = stages
    }
}

public struct SearchDocsRunOutput: Sendable {
    public let results: [SearchResult]
    public let instrumentation: DocumentationSearchInstrumentation

    public init(results: [SearchResult], instrumentation: DocumentationSearchInstrumentation) {
        self.results = results
        self.instrumentation = instrumentation
    }
}

public struct DocumentationUsageLogEntry: Codable, Sendable {
    public let operation: String
    public let caller: String?
    public let status: DocumentationUsageStatus
    public let query: String?
    public let id: String?
    public let category: String?
    public let localeIdentifier: String
    public let durationMs: Double
    public let resultCount: Int
    public let source: String?
    public let errorCategory: String?
    public let errorMessage: String?
    public let searchStages: [DocumentationSearchStageTiming]?

    enum CodingKeys: String, CodingKey {
        case operation
        case caller
        case status
        case query
        case id
        case category
        case localeIdentifier = "locale_identifier"
        case durationMs = "duration_ms"
        case resultCount = "result_count"
        case source
        case errorCategory = "error_category"
        case errorMessage = "error_message"
        case searchStages = "search_stages"
    }

    public init(
        operation: String,
        caller: String?,
        status: DocumentationUsageStatus,
        query: String? = nil,
        id: String? = nil,
        category: String? = nil,
        localeIdentifier: String,
        durationMs: Double,
        resultCount: Int,
        source: String?,
        errorCategory: String? = nil,
        errorMessage: String? = nil,
        searchStages: [DocumentationSearchStageTiming]? = nil
    ) {
        self.operation = operation
        self.caller = caller
        self.status = status
        self.query = query
        self.id = id
        self.category = category
        self.localeIdentifier = localeIdentifier
        self.durationMs = durationMs
        self.resultCount = resultCount
        self.source = source
        self.errorCategory = errorCategory
        self.errorMessage = errorMessage
        self.searchStages = searchStages
    }

    public func sanitized() -> DocumentationUsageLogEntry {
        DocumentationUsageLogEntry(
            operation: operation,
            caller: sanitize(caller),
            status: status,
            query: sanitize(query),
            id: sanitize(id),
            category: sanitize(category),
            localeIdentifier: localeIdentifier,
            durationMs: durationMs,
            resultCount: resultCount,
            source: source,
            errorCategory: errorCategory,
            errorMessage: sanitize(errorMessage),
            searchStages: searchStages
        )
    }

    private func sanitize(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return value }

        let patterns: [(String, String)] = [
            (#"file://\S+"#, "<redacted:file-url>"),
            (#"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, "<redacted:email>"),
            (#"\bsk-[A-Za-z0-9_-]{6,}\b"#, "<redacted:token>"),
            (#"(?:/Users|/home|/var|/private|/tmp|/Volumes)/[^\s]+"#, "<redacted:path>")
        ]

        return patterns.reduce(value) { partial, item in
            partial.replacingOccurrences(
                of: item.0,
                with: item.1,
                options: [.regularExpression, .caseInsensitive]
            )
        }
    }
}

public actor DocumentationUsageRecorder {
    public init() {}

    public func record(_ entry: DocumentationUsageLogEntry, to path: String) async throws {
        guard !path.isEmpty else { return }

        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry.sanitized())

        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data + Data("\n".utf8))
    }
}
