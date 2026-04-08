import Foundation
import Testing

@Suite("Benchmark Shared Scenario Tests")
struct BenchmarkSharedScenarioTests {
    @Test("Task matrix should include at least 12 shared scenarios")
    func sharedTaskCount() throws {
        let json = try BenchmarkFixtures.fixtureJSON("specs/008-mcp-service-benchmark/fixtures/task-matrix.json")
        let dict = try #require(json as? [String: Any])
        let shared = try #require(dict["sharedTasks"] as? [[String: Any]])
        #expect(shared.count >= 12)
    }
}
