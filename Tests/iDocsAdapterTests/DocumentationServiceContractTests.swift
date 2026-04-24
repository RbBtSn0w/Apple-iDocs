import Testing
import Foundation
@testable import iDocsAdapter

@Suite("iDocsAdapter Contract Tests")
struct DocumentationServiceContractTests {
    @Test("DocumentationConfig supports explicit injection values")
    func configInjection() {
        let config = DocumentationConfig(
            cachePath: "/tmp/idocs-tests",
            callerID: "skill.swiftui-engineering",
            usageLogPath: "/tmp/idocs-tests/usage.jsonl",
            technologyCategoryFilter: "framework",
            locale: Locale(identifier: "en_US"),
            timeout: 12,
            apiBaseURL: URL(string: "https://example.com")!,
            enableFileLocking: true
        )

        #expect(config.cachePath == "/tmp/idocs-tests")
        #expect(config.callerID == "skill.swiftui-engineering")
        #expect(config.usageLogPath == "/tmp/idocs-tests/usage.jsonl")
        #expect(config.technologyCategoryFilter == "framework")
        #expect(config.timeout == 12)
        #expect(config.apiBaseURL.absoluteString == "https://example.com")
        #expect(config.enableFileLocking)
    }

    @Test("Default CLI config provides cache path")
    func defaultCLIConfig() {
        let config = DocumentationConfig.cliDefault()
        #expect(config.cachePath.contains("iDocs"))
        #expect(config.usageLogPath?.contains("iDocs") == true)
    }

    @Test("Default CLI config honors environment overrides")
    func defaultCLIConfigHonorsEnvironmentOverrides() {
        let config = DocumentationConfig.cliDefault(
            environment: [
                "IDOCS_CACHE_PATH": "/tmp/idocs-custom-cache",
                "IDOCS_USAGE_LOG_PATH": "/tmp/idocs-custom-usage.jsonl",
            ]
        )

        #expect(config.cachePath == "/tmp/idocs-custom-cache")
        #expect(config.usageLogPath == "/tmp/idocs-custom-usage.jsonl")
        #expect(config.technologyCategoryFilter == nil)
    }

    @Test("Invocation context preserves existing technology category filter")
    func invocationContextPreservesExistingTechnologyCategoryFilter() {
        let config = DocumentationConfig(
            cachePath: "/tmp/idocs-tests",
            technologyCategoryFilter: "framework"
        )

        let updated = config.withInvocationContext(callerID: "skill.swiftui-engineering")

        #expect(updated.callerID == "skill.swiftui-engineering")
        #expect(updated.technologyCategoryFilter == "framework")
    }

    @Test("Invocation context explicitly overrides technology category filter")
    func invocationContextOverridesTechnologyCategoryFilter() {
        let config = DocumentationConfig(
            cachePath: "/tmp/idocs-tests",
            technologyCategoryFilter: "framework"
        )

        let updated = config.withInvocationContext(
            callerID: "skill.swiftui-engineering",
            technologyCategoryFilter: "service"
        )

        #expect(updated.callerID == "skill.swiftui-engineering")
        #expect(updated.technologyCategoryFilter == "service")
    }

    @Test("Invocation context explicitly clears technology category filter")
    func invocationContextClearsTechnologyCategoryFilter() {
        let config = DocumentationConfig(
            cachePath: "/tmp/idocs-tests",
            technologyCategoryFilter: "framework"
        )

        let updated = config.withInvocationContext(
            callerID: "skill.swiftui-engineering",
            technologyCategoryFilter: nil
        )

        #expect(updated.callerID == "skill.swiftui-engineering")
        #expect(updated.technologyCategoryFilter == nil)
    }

    @Test("DocumentationService exposes async API shape")
    func asyncAPIShape() async throws {
        struct StubService: DocumentationService {
            func search(query: String, config: DocumentationConfig) async throws -> [SearchResult] { [] }
            func fetch(id: String, config: DocumentationConfig) async throws -> DocumentationContent {
                DocumentationContent(title: id, body: "", url: URL(string: "https://example.com")!)
            }
            func listTechnologies(config: DocumentationConfig) async throws -> [Technology] { [] }
            func getCoreVersion() -> String { "1.0.0" }
        }

        let service = StubService()
        let config = DocumentationConfig(cachePath: "/tmp")

        let search = try await service.search(query: "SwiftUI", config: config)
        let fetch = try await service.fetch(id: "/documentation/swiftui/view", config: config)
        let list = try await service.listTechnologies(config: config)

        #expect(search.isEmpty)
        #expect(fetch.title == "/documentation/swiftui/view")
        #expect(list.isEmpty)
    }

    @Test("SearchResult source field is preserved through adapter contract")
    func searchResultSourceRoundTrip() async throws {
        let expected = SearchResult(
            id: "/documentation/swiftui/view",
            title: "View",
            snippet: "A view",
            technology: "swiftui",
            source: .sosumi
        )

        let service = MockDocumentationAdapter(searchResults: [expected])
        let config = DocumentationConfig(cachePath: "/tmp")
        let results = try await service.search(query: "View", config: config)

        #expect(results.count == 1)
        #expect(results[0].source == .sosumi)
    }

    struct DocumentationErrorScenario: Sendable {
        let error: DocumentationError
        let expectedDescription: String
    }

    @Test(
        "DocumentationError exposes stable localized descriptions",
        arguments: [
            DocumentationErrorScenario(
                error: .notFound(id: "/documentation/swiftui/view"),
                expectedDescription: "Documentation for '/documentation/swiftui/view' could not be found."
            ),
            DocumentationErrorScenario(
                error: .networkError(message: "timeout"),
                expectedDescription: "Network error: timeout"
            ),
            DocumentationErrorScenario(
                error: .parsingError(reason: "invalid payload"),
                expectedDescription: "Parsing error: invalid payload"
            ),
            DocumentationErrorScenario(
                error: .unauthorized,
                expectedDescription: "Unauthorized access."
            ),
            DocumentationErrorScenario(
                error: .invalidConfiguration(message: "missing cache path"),
                expectedDescription: "Invalid configuration: missing cache path"
            ),
            DocumentationErrorScenario(
                error: .incompatibleVersion(adapter: "2.0.0", core: "1.0.0"),
                expectedDescription: "Incompatible adapter/core versions. adapter=2.0.0, core=1.0.0"
            ),
            DocumentationErrorScenario(
                error: .internalError(message: "unexpected nil"),
                expectedDescription: "Internal error: unexpected nil"
            )
        ]
    )
    func documentationErrorDescriptions(scenario: DocumentationErrorScenario) {
        #expect(scenario.error.errorDescription == scenario.expectedDescription)
        #expect(scenario.error.localizedDescription == scenario.expectedDescription)
    }
}
