import Testing
@testable import iDocsApp

@Suite("Benchmark Rubric Tests")
struct BenchmarkRubricTests {
    @Test("Base weights should total 100")
    func baseWeightTotal() {
        #expect(BenchmarkDimensionWeights.default.total == 100)
    }

    @Test("Format readiness weights should total 100")
    func formatWeightTotal() {
        #expect(FormatReadinessWeights.default.total == 100)
    }

    @Test("Diagnosability scoring should map from 0 to max")
    func diagnosabilityScoreMapping() {
        #expect(BenchmarkScoring.diagnosabilityScore(level: .silentFailure) == 0)
        #expect(BenchmarkScoring.diagnosabilityScore(level: .actionableReason) == 10)
    }
}
