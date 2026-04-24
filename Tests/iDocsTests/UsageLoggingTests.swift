import Foundation
import Testing
@testable import iDocsAdapter
@testable import iDocsKit

@Suite("Usage Logging Tests")
struct UsageLoggingTests {
    @Test("Usage recorder sanitizes sensitive values before writing JSONL")
    func usageRecorderSanitizesSensitiveValues() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let logURL = temporaryDirectory.appendingPathComponent("usage.jsonl")
        let recorder = DocumentationUsageRecorder()

        let entry = DocumentationUsageLogEntry(
            operation: "search",
            caller: "skill.swiftui-engineering",
            status: .success,
            query: "Open file:///Users/alice/Secrets.swift or email alice@example.com with sk-1234567890 and /Users/alice/project/.env",
            localeIdentifier: "en_US_POSIX",
            durationMs: 12.5,
            resultCount: 1,
            source: "local",
            searchStages: [
                DocumentationSearchStageTiming(
                    name: "local",
                    status: .hit,
                    durationMs: 4.0,
                    resultCount: 1
                )
            ]
        )

        try await recorder.record(entry, to: logURL.path)

        let payload = try readSingleLogEntry(from: logURL)
        let query = try #require(payload["query"] as? String)

        #expect(query.contains("<redacted:file-url>"))
        #expect(query.contains("<redacted:email>"))
        #expect(query.contains("<redacted:token>"))
        #expect(query.contains("<redacted:path>"))
        #expect(!query.contains("alice@example.com"))
        #expect(!query.contains("/Users/alice"))
        #expect(!query.contains("sk-1234567890"))
        #expect(payload["operation"] as? String == "search")
        #expect(payload["caller"] as? String == "skill.swiftui-engineering")
        #expect(payload["status"] as? String == "success")
        #expect(payload["source"] as? String == "local")
        #expect((payload["search_stages"] as? [[String: Any]])?.count == 1)
    }

    @Test("SearchDocsTool detailed run records stage timings")
    func searchDocsToolDetailedRunRecordsStageTimings() async throws {
        let tool = SearchDocsTool(
            api: makeMockAppleAPI(queries: ["View"]),
            sosumiAPI: makeMockSosumiAPI(queries: ["View"]),
            xcodeDocs: XcodeLocalDocs(
                fileManager: MockFileSystem(),
                searchProvider: MockSearchProvider()
            ),
            memoryCache: MemoryCache<String, [iDocsKit.SearchResult]>(capacity: 5)
        )

        let output = try await tool.runDetailed(query: "View")

        #expect(!output.results.isEmpty)
        #expect(output.instrumentation.finalSource == "apple")
        #expect(output.instrumentation.totalDurationMs >= 0)
        #expect(output.instrumentation.stages.count == 3)
        #expect(output.instrumentation.stages.map { $0.name } == ["cache", "local", "apple"])
        #expect(
            output.instrumentation.stages.map { $0.status }
                == [
                    DocumentationSearchStageStatus.miss,
                    DocumentationSearchStageStatus.miss,
                    DocumentationSearchStageStatus.hit
                ]
        )
        #expect(output.instrumentation.stages.allSatisfy { $0.durationMs >= 0 })
        #expect(output.instrumentation.stages[2].resultCount == output.results.count)
    }

    @Test("SearchDocsTool returns empty results when remote fallbacks time out")
    func searchDocsToolReturnsEmptyResultsOnRemoteTimeout() async throws {
        let tool = SearchDocsTool(
            api: AppleJSONAPI(session: TimeoutNetworkSession()),
            sosumiAPI: SosumiAPI(session: TimeoutNetworkSession()),
            xcodeDocs: XcodeLocalDocs(
                fileManager: MockFileSystem(),
                searchProvider: MockSearchProvider()
            ),
            memoryCache: MemoryCache<String, [iDocsKit.SearchResult]>(capacity: 5),
            remoteSearchTimeoutSeconds: 0.05
        )

        let output = try await tool.runDetailed(query: "qwertyzzdocnotfound")

        #expect(output.results.isEmpty)
        #expect(output.instrumentation.stages.count == 4)
        #expect(output.instrumentation.stages.map { $0.name } == ["cache", "local", "apple", "sosumi"])
        #expect(output.instrumentation.stages[2].status == .error)
        #expect(output.instrumentation.stages[3].status == .error)
        #expect(output.instrumentation.totalDurationMs < 500)
    }

    @Test("DefaultDocumentationAdapter writes sanitized search usage log with timings")
    func adapterWritesSanitizedSearchUsageLog() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let logURL = temporaryDirectory.appendingPathComponent("usage.jsonl")
        let config = DocumentationConfig(
            cachePath: temporaryDirectory.appendingPathComponent("cache").path,
            callerID: "skill.swiftui-engineering",
            usageLogPath: logURL.path
        )

        let toolResult = SearchDocsRunOutput(
            results: [
                iDocsKit.SearchResult(
                    title: "View",
                    abstract: "SwiftUI view",
                    path: "/documentation/swiftui/view",
                    kind: .structure,
                    source: .local
                )
            ],
            instrumentation: DocumentationSearchInstrumentation(
                totalDurationMs: 9.0,
                finalSource: "local",
                stages: [
                    DocumentationSearchStageTiming(name: "cache", status: .miss, durationMs: 1.0, resultCount: 0),
                    DocumentationSearchStageTiming(name: "local", status: .hit, durationMs: 3.5, resultCount: 1)
                ]
            )
        )

        let adapter = try DefaultDocumentationAdapter(
            searchPerformer: { query in
                #expect(query == "find /Users/alice/project/View.swift")
                return toolResult
            }
        )

        let results = try await adapter.search(query: "find /Users/alice/project/View.swift", config: config)
        #expect(results.count == 1)
        #expect(results.first?.source == .local)

        let payload = try readSingleLogEntry(from: logURL)
        let query = try #require(payload["query"] as? String)
        let stages = try #require(payload["search_stages"] as? [[String: Any]])

        #expect(payload["operation"] as? String == "search")
        #expect(payload["caller"] as? String == "skill.swiftui-engineering")
        #expect(payload["status"] as? String == "success")
        #expect(payload["source"] as? String == "local")
        #expect(payload["result_count"] as? Int == 1)
        #expect(query.contains("<redacted:path>"))
        #expect(!query.contains("/Users/alice"))
        #expect(stages.count == 2)
        #expect(stages.compactMap { $0["name"] as? String } == ["cache", "local"])
    }

    @Test("DefaultDocumentationAdapter logs filtered technology count for category list requests")
    func adapterLogsFilteredTechnologyCountForListRequests() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let logURL = temporaryDirectory.appendingPathComponent("usage.jsonl")
        let config = DocumentationConfig(
            cachePath: temporaryDirectory.appendingPathComponent("cache").path,
            callerID: "skill.swiftui-engineering",
            usageLogPath: logURL.path,
            technologyCategoryFilter: "framework"
        )

        let adapter = try DefaultDocumentationAdapter(
            technologiesPerformer: {
                [
                    Technology(name: "SwiftUI", id: "/documentation/swiftui", category: "framework"),
                    Technology(name: "CloudKit", id: "/documentation/cloudkit", category: "service")
                ]
            }
        )
        let results = try await adapter.listTechnologies(config: config)

        let payload = try readSingleLogEntry(from: logURL)

        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.category?.localizedCaseInsensitiveContains("framework") == true })
        #expect(payload["operation"] as? String == "list")
        #expect(payload["caller"] as? String == "skill.swiftui-engineering")
        #expect(payload["category"] as? String == "framework")
        #expect(payload["result_count"] as? Int == results.count)
        #expect(payload["source"] as? String == "apple")
    }

    private func makeMockAppleAPI(queries: [String]) -> AppleJSONAPI {
        let session = MockNetworkSession()
        for query in queries {
            if let url = URLHelpers.searchURL(query: query) {
                session.setResponse(
                    for: url,
                    data: MockPayloads.searchJSON,
                    response: MockPayloads.httpResponse(url: url)
                )
            }
        }
        return AppleJSONAPI(session: session)
    }

    private func makeMockSosumiAPI(queries: [String]) -> SosumiAPI {
        let session = MockNetworkSession()
        for query in queries {
            if let url = URLHelpers.sosumiSearchURL(query: query) {
                session.setResponse(
                    for: url,
                    data: MockPayloads.sosumiSearchJSON,
                    response: MockPayloads.httpResponse(url: url)
                )
            }
        }
        return SosumiAPI(session: session)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func readSingleLogEntry(from url: URL) throws -> [String: Any] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let line = try #require(
            contents
                .split(separator: "\n")
                .map(String.init)
                .first
        )
        let data = try #require(line.data(using: .utf8))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private struct TimeoutNetworkSession: NetworkSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        throw MockError.networkTimeout
    }
}
