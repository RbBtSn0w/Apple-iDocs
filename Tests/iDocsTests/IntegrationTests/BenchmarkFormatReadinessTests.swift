import Testing
@testable import iDocsApp

@Suite("Benchmark Format Readiness Tests")
struct BenchmarkFormatReadinessTests {
    @Test("Format readiness should produce bounded score")
    func readinessRange() {
        let score = BenchmarkScoring.formatReadinessScore(
            extractability: 5,
            density: 3,
            taskFit: 5,
            noise: 3,
            citability: 5
        )
        #expect(score > 0)
        #expect(score <= 100)
    }
}
