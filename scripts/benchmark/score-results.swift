#!/usr/bin/env swift
import Foundation

struct AggregateFile: Decodable {
    let aggregates: [Aggregate]
}

struct Aggregate: Decodable {
    let target_id: String
    let scenario_id: String
    let success_rate: Double
    let mean_duration_ms: Double
    let avg_total_token_per_task: Double?
    let stddev_duration_ms: Double
    let overfetch_rate: Double
    let avg_claim_rate: Double?
    let avg_slot_rate: Double?
    let scored_sample_count: Int
    let unscored_sample_count: Int
    let needs_review_count: Int
}

struct TargetScore: Encodable {
    let target_id: String
    let accuracy: Double
    let completeness: Double
    let efficiency: Double
    let token_cost: Double
    let stability: Double
    let diagnosability: Double
    let overfetch_penalty: Double
    let needs_review_count: Int
    let unscored_sample_count: Int
    let total_score: Double
}

func normalizeLowerBetter(_ value: Double, floor: Double, ceil: Double) -> Double {
    if value <= floor { return 1 }
    if value >= ceil { return 0 }
    return 1 - ((value - floor) / (ceil - floor))
}

func overfetchPenalty(rate: Double) -> Double {
    if rate >= 0.50 { return 12 }
    if rate >= 0.25 { return 7 }
    if rate >= 0.10 { return 3 }
    return 0
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    fputs("usage: score-results.swift <aggregates.json> <output.json>\n", stderr)
    exit(1)
}

let data = try Data(contentsOf: URL(fileURLWithPath: args[1]))
let file = try JSONDecoder().decode(AggregateFile.self, from: data)

let groups = Dictionary(grouping: file.aggregates) { $0.target_id }
var scores: [TargetScore] = []

for (target, rows) in groups {
    let avgDuration = rows.map(\.mean_duration_ms).reduce(0, +) / Double(rows.count)
    let tokenRows = rows.compactMap(\.avg_total_token_per_task)
    let avgToken = tokenRows.isEmpty ? 0 : tokenRows.reduce(0, +) / Double(tokenRows.count)
    let avgStddev = rows.map(\.stddev_duration_ms).reduce(0, +) / Double(rows.count)
    let avgOverfetch = rows.map(\.overfetch_rate).reduce(0, +) / Double(rows.count)
    let claimRows = rows.compactMap(\.avg_claim_rate)
    let slotRows = rows.compactMap(\.avg_slot_rate)
    let avgClaimRate = claimRows.isEmpty ? 0 : claimRows.reduce(0, +) / Double(claimRows.count)
    let avgSlotRate = slotRows.isEmpty ? 0 : slotRows.reduce(0, +) / Double(slotRows.count)
    let needsReviewCount = rows.map(\.needs_review_count).reduce(0, +)
    let unscoredCount = rows.map(\.unscored_sample_count).reduce(0, +)

    let accuracy = max(0, min(1, avgClaimRate)) * 35
    let completeness = max(0, min(1, avgSlotRate)) * 20
    let efficiency = normalizeLowerBetter(avgDuration, floor: 100, ceil: 6000) * 15
    let tokenCost = normalizeLowerBetter(avgToken, floor: 200, ceil: 12000) * 10
    let stability = normalizeLowerBetter(avgStddev, floor: 20, ceil: 2000) * 10
    let diagnosability = 8.0
    let penalty = overfetchPenalty(rate: avgOverfetch)
    let total = max(0, accuracy + completeness + efficiency + tokenCost + stability + diagnosability - penalty)

    scores.append(
        TargetScore(
            target_id: target,
            accuracy: accuracy,
            completeness: completeness,
            efficiency: efficiency,
            token_cost: tokenCost,
            stability: stability,
            diagnosability: diagnosability,
            overfetch_penalty: penalty,
            needs_review_count: needsReviewCount,
            unscored_sample_count: unscoredCount,
            total_score: total
        )
    )
}

let outURL = URL(fileURLWithPath: args[2])
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(["target_scores": scores]).write(to: outURL)
