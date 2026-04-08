import Foundation

public enum BenchmarkSampleClass: String, Codable, Sendable {
    case cold
    case warm
}

public enum BenchmarkRunStatus: String, Codable, Sendable {
    case success
    case failure
    case partial
    case notApplicable = "not-applicable"
}

public enum TokenObservability: String, Codable, Sendable {
    case full
    case partial
    case none
}

public enum BenchmarkErrorCategory: String, Codable, Sendable {
    case timeout
    case network
    case notFound = "not_found"
    case invalidInput = "invalid_input"
    case serviceUnavailable = "service_unavailable"
    case rateLimited = "rate_limited"
    case `internal`
    case unknown
}

public struct BenchmarkExecutionRecord: Codable, Sendable {
    public let runID: String
    public let targetID: String
    public let scenarioID: String
    public let attemptIndex: Int
    public let sampleClass: BenchmarkSampleClass
    public let status: BenchmarkRunStatus
    public let startedAt: Date
    public let finishedAt: Date
    public let durationMs: Int
    public let callCount: Int
    public let outputLength: Int
    public let avgTokenPerCall: Int?
    public let totalTokenPerTask: Int?
    public let tokenObservability: TokenObservability
    public let tokenizerSpec: String
    public let driverProfile: String
    public let truthBaseline: String
    public let overfetchFlag: Bool
    public let errorCategory: BenchmarkErrorCategory?
    public let evidenceRefs: [String]
    public let normalizedEvidenceRef: String?
    public let assertionRef: String?
    public let accuracyVerdict: String
    public let completenessVerdict: String
    public let claimRate: Double
    public let slotRate: Double
    public let claimBreakdown: [String: Int]?
    public let slotBreakdown: [String: Int]?
    public let judgeVerdict: String?
    public let judgeConfidence: Double?
    public let judgeReason: String?
    public let needsReview: Bool?
    public let scoredSample: Bool?
    public let reviewerNotes: String?
    public let formatExtractability: Int
    public let formatDensity: Int
    public let formatTaskFit: Int
    public let formatNoise: Int
    public let formatCitability: Int
    public let formatNotes: String

    enum CodingKeys: String, CodingKey {
        case runID = "run_id"
        case targetID = "target_id"
        case scenarioID = "scenario_id"
        case attemptIndex = "attempt_index"
        case sampleClass = "sample_class"
        case status
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case durationMs = "duration_ms"
        case callCount = "call_count"
        case outputLength = "output_length"
        case avgTokenPerCall = "avg_token_per_call"
        case totalTokenPerTask = "total_token_per_task"
        case tokenObservability = "token_observability"
        case tokenizerSpec = "tokenizer_spec"
        case driverProfile = "driver_profile"
        case truthBaseline = "truth_baseline"
        case overfetchFlag = "overfetch_flag"
        case errorCategory = "error_category"
        case evidenceRefs = "evidence_refs"
        case normalizedEvidenceRef = "normalized_evidence_ref"
        case assertionRef = "assertion_ref"
        case accuracyVerdict = "accuracy_verdict"
        case completenessVerdict = "completeness_verdict"
        case claimRate = "claim_rate"
        case slotRate = "slot_rate"
        case claimBreakdown = "claim_breakdown"
        case slotBreakdown = "slot_breakdown"
        case judgeVerdict = "judge_verdict"
        case judgeConfidence = "judge_confidence"
        case judgeReason = "judge_reason"
        case needsReview = "needs_review"
        case scoredSample = "scored_sample"
        case reviewerNotes = "reviewer_notes"
        case formatExtractability = "format_extractability"
        case formatDensity = "format_density"
        case formatTaskFit = "format_task_fit"
        case formatNoise = "format_noise"
        case formatCitability = "format_citability"
        case formatNotes = "format_notes"
    }
}

public struct BenchmarkAggregate: Codable, Sendable {
    public let targetID: String
    public let scenarioID: String
    public let sampleCount: Int
    public let scoredSampleCount: Int
    public let unscoredSampleCount: Int
    public let needsReviewCount: Int
    public let successRate: Double
    public let timeoutRate: Double
    public let meanDurationMs: Double
    public let p50DurationMs: Double
    public let p90DurationMs: Double
    public let p99DurationMs: Double?
    public let insufficientP99Sample: Bool
    public let stddevDurationMs: Double
    public let avgCallCount: Double
    public let avgTokenPerCall: Double?
    public let avgTotalTokenPerTask: Double?
    public let overfetchRate: Double
    public let avgClaimRate: Double?
    public let avgSlotRate: Double?

    enum CodingKeys: String, CodingKey {
        case targetID = "target_id"
        case scenarioID = "scenario_id"
        case sampleCount = "sample_count"
        case scoredSampleCount = "scored_sample_count"
        case unscoredSampleCount = "unscored_sample_count"
        case needsReviewCount = "needs_review_count"
        case successRate = "success_rate"
        case timeoutRate = "timeout_rate"
        case meanDurationMs = "mean_duration_ms"
        case p50DurationMs = "p50_duration_ms"
        case p90DurationMs = "p90_duration_ms"
        case p99DurationMs = "p99_duration_ms"
        case insufficientP99Sample = "insufficient_p99_sample"
        case stddevDurationMs = "stddev_duration_ms"
        case avgCallCount = "avg_call_count"
        case avgTokenPerCall = "avg_token_per_call"
        case avgTotalTokenPerTask = "avg_total_token_per_task"
        case overfetchRate = "overfetch_rate"
        case avgClaimRate = "avg_claim_rate"
        case avgSlotRate = "avg_slot_rate"
    }
}

public enum BenchmarkStats {
    public static func percentile(_ values: [Int], p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let rank = p * Double(sorted.count - 1)
        let lower = Int(floor(rank))
        let upper = Int(ceil(rank))
        if lower == upper { return Double(sorted[lower]) }
        let weight = rank - Double(lower)
        return Double(sorted[lower]) * (1 - weight) + Double(sorted[upper]) * weight
    }

    public static func mean(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    public static func stddev(_ values: [Int]) -> Double {
        guard values.count > 1 else { return 0 }
        let average = mean(values)
        let variance = values.map { pow(Double($0) - average, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}
