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

    @Test("SearchDocsTool distinguishes permission failure from remote no-result miss")
    func searchDocsToolDistinguishesPermissionFailureFromNoResultMiss() async throws {
        let appleSession = MockNetworkSession(
            stubbedError: NSError(
                domain: NSPOSIXErrorDomain,
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Operation not permitted"]
            )
        )
        let sosumiSession = MockNetworkSession()
        let query = "NavigationSplitView"
        let sosumiURL = try #require(URLHelpers.sosumiSearchURL(query: query))
        sosumiSession.setResponse(
            for: sosumiURL,
            data: MockPayloads.emptySosumiSearchJSON,
            response: MockPayloads.httpResponse(url: sosumiURL)
        )
        let tool = SearchDocsTool(
            api: AppleJSONAPI(session: appleSession),
            sosumiAPI: SosumiAPI(session: sosumiSession),
            xcodeDocs: XcodeLocalDocs(
                fileManager: MockFileSystem(),
                searchProvider: MockSearchProvider()
            ),
            memoryCache: MemoryCache<String, [iDocsKit.SearchResult]>(capacity: 5),
            remoteSearchTimeoutSeconds: 0
        )

        let output = try await tool.runDetailed(query: query)
        let appleStage = try #require(output.instrumentation.stages.first { $0.name == "apple" })
        let sosumiStage = try #require(output.instrumentation.stages.first { $0.name == "sosumi" })

        #expect(output.results.isEmpty)
        #expect(appleStage.status == .error)
        #expect(appleStage.reason == "remote_permission_denied")
        #expect(appleStage.hint?.contains("network permission") == true)
        #expect(sosumiStage.status == .miss)
        #expect(sosumiStage.reason == "remote_no_results")
        #expect(sosumiStage.hint?.contains("search-quality miss") == true)
    }

    @Test("SearchDocsTool reports missing local documentation cache as degradation")
    func searchDocsToolReportsMissingLocalDocsAsDegradation() async throws {
        let query = "View"
        let tool = SearchDocsTool(
            api: makeMockAppleAPI(queries: [query]),
            sosumiAPI: makeMockSosumiAPI(queries: [query]),
            xcodeDocs: XcodeLocalDocs(
                fileManager: MockFileSystem(),
                searchProvider: MockSearchProvider(),
                cacheDirectory: URL(fileURLWithPath: "/tmp/missing-xcode-doc-cache")
            ),
            memoryCache: MemoryCache<String, [iDocsKit.SearchResult]>(capacity: 5)
        )

        let output = try await tool.runDetailed(query: query)
        let localStage = try #require(output.instrumentation.stages.first { $0.name == "local" })

        #expect(!output.results.isEmpty)
        #expect(localStage.reason == "local_docs_unavailable")
        #expect(localStage.hint?.contains("remote-only") == true)
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

    @Test("DefaultDocumentationAdapter reuses injected API clients across fetch and list paths")
    func adapterReusesInjectedAPIClientsAcrossFetchAndListPaths() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let appleSession = MockNetworkSession()
        let sosumiSession = MockNetworkSession()
        let fetchPath = "/documentation/swiftui/view"
        let fetchURL = try #require(URLHelpers.dataURL(for: fetchPath))
        let technologiesURL = try #require(URLHelpers.technologiesURL())

        appleSession.setResponse(
            for: fetchURL,
            data: MockPayloads.docCJSONWithObjectIdentifier(
                title: "View",
                identifierURL: "doc://com.apple.documentation/documentation/swiftui/view",
                abstract: "A SwiftUI view."
            ),
            response: MockPayloads.httpResponse(url: fetchURL)
        )
        appleSession.setResponse(
            for: technologiesURL,
            data: MockPayloads.technologiesJSON,
            response: MockPayloads.httpResponse(url: technologiesURL)
        )

        let adapter = try DefaultDocumentationAdapter(
            appleAPI: AppleJSONAPI(session: appleSession),
            sosumiAPI: SosumiAPI(session: sosumiSession)
        )
        let config = DocumentationConfig(cachePath: temporaryDirectory.appendingPathComponent("cache").path)

        _ = try await adapter.fetch(id: fetchPath, config: config)
        let technologies = try await adapter.listTechnologies(config: config)

        #expect(!technologies.isEmpty)
        #expect(appleSession.requestCount == 2)
        #expect(appleSession.requestedURLs == [fetchURL, technologiesURL])
        #expect(sosumiSession.requestCount == 0)
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
