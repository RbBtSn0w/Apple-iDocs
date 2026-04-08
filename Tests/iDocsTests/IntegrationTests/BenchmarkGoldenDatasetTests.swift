import Foundation
import Testing

@Suite("Benchmark Golden Dataset Tests")
struct BenchmarkGoldenDatasetTests {
    @Test("Golden dataset should include frozen atomic claims and required slots")
    func validateGoldenDataset() throws {
        let json = try BenchmarkFixtures.fixtureJSON("specs/008-mcp-service-benchmark/fixtures/golden-dataset.json")
        let dict = try #require(json as? [String: Any])
        let scenarios = try #require(dict["scenarios"] as? [[String: Any]])
        #expect(!scenarios.isEmpty)

        for scenario in scenarios {
            let atomicClaims = try #require(scenario["atomicClaims"] as? [String])
            let requiredSlots = try #require(scenario["requiredSlots"] as? [String])
            #expect(!atomicClaims.isEmpty)
            #expect(!requiredSlots.isEmpty)
        }
    }

    @Test("Tokenizer spec should pin cl100k_base")
    func validateTokenizerSpec() throws {
        let json = try BenchmarkFixtures.fixtureJSON("specs/008-mcp-service-benchmark/fixtures/tokenizer-spec.json")
        let dict = try #require(json as? [String: Any])
        #expect(dict["tokenizerSpec"] as? String == "cl100k_base")
    }
}
