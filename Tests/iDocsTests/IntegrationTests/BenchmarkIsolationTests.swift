import Foundation
import Testing

@Suite("Benchmark Isolation Tests")
struct BenchmarkIsolationTests {
    @Test("Run manifest should separate cold and warm sample counts")
    func samplePlan() throws {
        let json = try BenchmarkFixtures.fixtureJSON("specs/008-mcp-service-benchmark/fixtures/run-manifest.json")
        let dict = try #require(json as? [String: Any])
        let plan = try #require(dict["samplePlan"] as? [String: Int])
        #expect((plan["cold"] ?? 0) >= 1)
        #expect((plan["warm"] ?? 0) >= 1)
    }
}
