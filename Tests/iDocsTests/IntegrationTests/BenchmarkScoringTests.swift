import Testing
@testable import iDocsApp

@Suite("Benchmark Scoring Tests")
struct BenchmarkScoringTests {
    @Test("Accuracy score should be derived from atomic claim rate")
    func accuracyRate() {
        let verdict = AtomicClaimVerdict(correct: 8, incorrect: 1, missing: 1, unverifiable: 0)
        let score = BenchmarkScoring.scoreByRate(verdict.accuracyRate, weight: 35)
        #expect(score == 28)
    }

    @Test("Overfetch penalty should reduce score")
    func overfetchPenalty() {
        let base = 80.0
        let reduced = BenchmarkScoring.applyOverfetchPenalty(baseScore: base, overfetchLevel: "moderate")
        #expect(reduced == 73)
    }
}
