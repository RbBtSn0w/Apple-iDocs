import Foundation
import Testing

@Suite("Benchmark Repeatability Tests")
struct BenchmarkRepeatabilityTests {
    @Test("Manifest and truth baseline should be pinned")
    func baselinePinning() throws {
        let runManifestJSON = try BenchmarkFixtures.fixtureJSON("specs/008-mcp-service-benchmark/fixtures/run-manifest.json")
        let baselineJSON = try BenchmarkFixtures.fixtureJSON("specs/008-mcp-service-benchmark/fixtures/truth-baseline.json")

        let runManifest = try #require(runManifestJSON as? [String: Any])
        let baseline = try #require(baselineJSON as? [String: Any])
        #expect((runManifest["truthBaseline"] as? String) == (baseline["truthBaselineId"] as? String))
    }
}
