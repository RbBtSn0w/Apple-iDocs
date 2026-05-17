import Testing
import Foundation
@testable import iDocsKit

@Suite("ResolveDocsTool Tests")
struct ResolveDocsToolTests {
    @Test("ResolveDocsTool verifies exact symbol direct path")
    func exactSymbolDirectPath() async throws {
        let tool = ResolveDocsTool(
            fetch: { path in
                #expect(path == "/documentation/swiftui/navigationsplitview")
                return FetchDocResult(
                    markdown: "# NavigationSplitView\n\nA view that presents columns.",
                    source: .apple,
                    sourceAttempts: [FetchSourceAttempt(source: .apple, status: .hit)]
                )
            }
        )

        let result = try await tool.run(
            intent: ResolveDocsIntent(framework: "SwiftUI", symbol: "NavigationSplitView")
        )

        #expect(result.canonicalPath == "/documentation/swiftui/navigationsplitview")
        #expect(result.confidence == .high)
        #expect(result.verifiedByFetch)
        #expect(result.evidence?.source == .apple)
        #expect(result.evidence?.sourceFamily == "documentation")
        #expect(result.candidates.first?.source == .direct)
        #expect(result.resolveDiagnostics.contains { $0.stage == "direct_path" && $0.status == "hit" })
    }

    @Test("ResolveDocsTool defaults source family to documentation")
    func sourceFamilyDefaultsToDocumentation() async throws {
        let tool = ResolveDocsTool(fetch: successfulFetch(title: "View"))
        let result = try await tool.run(intent: ResolveDocsIntent(framework: "SwiftUI", type: "View"))

        #expect(result.evidence?.sourceFamily == "documentation")
    }

    @Test("ResolveDocsTool can recover known DocC member signature paths")
    func knownMemberSignaturePath() async throws {
        let recorder = PathRecorder()
        let tool = ResolveDocsTool(
            fetch: { path in
                await recorder.record(path)
                if path == "/documentation/uikit/uiviewcontroller/present" {
                    throw iDocsError.aggregateFetchFailure(
                        path: path,
                        attempts: [
                            FetchSourceAttempt(source: .apple, status: .error, reason: "http_404", statusCode: 404)
                        ]
                    )
                }
                #expect(path == "/documentation/uikit/uiviewcontroller/present(_:animated:completion:)")
                return FetchDocResult(
                    markdown: "# present(_:animated:completion:)\n\nPresents a view controller.",
                    source: .sosumi,
                    sourceAttempts: [FetchSourceAttempt(source: .sosumi, status: .hit)]
                )
            }
        )

        let result = try await tool.run(
            intent: ResolveDocsIntent(
                framework: "UIKit",
                type: "UIViewController",
                member: "present",
                memberKind: "method"
            )
        )

        #expect(await recorder.paths == [
            "/documentation/uikit/uiviewcontroller/present",
            "/documentation/uikit/uiviewcontroller/present(_:animated:completion:)"
        ])
        #expect(result.canonicalPath == "/documentation/uikit/uiviewcontroller/present(_:animated:completion:)")
        #expect(result.confidence == .high)
        #expect(result.verifiedByFetch)
    }

    @Test("ResolveDocsTool rejects member without type")
    func rejectsMemberWithoutType() async throws {
        let tool = ResolveDocsTool(fetch: successfulFetch(title: "body"))

        await #expect(throws: ResolveDocsError.invalidIntent("member requires type")) {
            _ = try await tool.run(intent: ResolveDocsIntent(framework: "SwiftUI", member: "body"))
        }
    }

    @Test("ResolveDocsTool does not return high confidence when direct fetch fails")
    func directFetchFailurePreventsHighConfidence() async throws {
        let tool = ResolveDocsTool(
            fetch: { path in
                throw iDocsError.aggregateFetchFailure(
                    path: path,
                    attempts: [
                        FetchSourceAttempt(source: .apple, status: .error, reason: "http_404", statusCode: 404)
                    ]
                )
            }
        )

        let result = try await tool.run(intent: ResolveDocsIntent(framework: "SwiftUI", symbol: "MissingSymbol"))

        #expect(result.confidence == .unresolved)
        #expect(result.verifiedByFetch == false)
        #expect(result.candidates.first?.verifiedByFetch == false)
        #expect(result.fetchDiagnostics?.first?.reason == "http_404")
    }

    @Test("ResolveDocsTool search fallback cannot override missing fetch evidence")
    func fallbackCannotOverrideMissingFetchEvidence() async throws {
        let tool = ResolveDocsTool(
            fetch: { path in
                throw iDocsError.aggregateFetchFailure(
                    path: path,
                    attempts: [
                        FetchSourceAttempt(source: .apple, status: .error, reason: "http_404", statusCode: 404)
                    ]
                )
            },
            search: { query in
                #expect(query == "SwiftUI MissingSymbol")
                return [
                    SearchResult(
                        title: "MissingSymbol",
                        abstract: "A fallback candidate.",
                        path: "/documentation/swiftui/missingsymbol",
                        kind: .structure,
                        source: .apple,
                        sourceKind: .documentation,
                        fetchSupported: true,
                        matchScope: .symbol
                    )
                ]
            }
        )

        let result = try await tool.run(intent: ResolveDocsIntent(framework: "SwiftUI", symbol: "MissingSymbol"))

        #expect(result.confidence == .unresolved)
        #expect(result.verifiedByFetch == false)
        #expect(result.candidates.contains { $0.source == .searchFallback && $0.verifiedByFetch == false })
    }

    private func successfulFetch(title: String) -> @Sendable (String) async throws -> FetchDocResult {
        { _ in
            FetchDocResult(
                markdown: "# \(title)\n\nFetched content.",
                source: .local,
                sourceAttempts: [FetchSourceAttempt(source: .local, status: .hit)]
            )
        }
    }
}

private actor PathRecorder {
    private(set) var paths: [String] = []

    func record(_ path: String) {
        paths.append(path)
    }
}
