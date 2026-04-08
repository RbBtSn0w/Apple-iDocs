import Foundation
import Testing

@Suite("Benchmark Target Availability Tests")
struct BenchmarkTargetAvailabilityTests {
    @Test("Target registry should include four benchmark targets")
    func targetsCount() throws {
        let json = try BenchmarkFixtures.fixtureJSON("specs/008-mcp-service-benchmark/fixtures/targets.json")
        let dict = try #require(json as? [String: Any])
        let targets = try #require(dict["targets"] as? [[String: Any]])
        #expect(targets.count == 4)
    }

    @Test("Minimum probes should define one probe per target")
    func minimumProbes() throws {
        let json = try BenchmarkFixtures.fixtureJSON("specs/008-mcp-service-benchmark/fixtures/minimum-probes.json")
        let dict = try #require(json as? [String: Any])
        let probes = try #require(dict["probes"] as? [[String: Any]])
        #expect(probes.count == 4)
    }
}
