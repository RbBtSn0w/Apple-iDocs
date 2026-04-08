#!/usr/bin/env swift
import Foundation

struct Record: Decodable {
    let target_id: String
    let scenario_id: String
    let status: String
    let duration_ms: Int
    let call_count: Int
    let avg_token_per_call: Int?
    let total_token_per_task: Int?
    let overfetch_flag: Bool
    let error_category: String?
    let claim_rate: Double?
    let slot_rate: Double?
    let needs_review: Bool?
    let scored_sample: Bool?
}

struct Aggregate: Encodable {
    let target_id: String
    let scenario_id: String
    let sample_count: Int
    let scored_sample_count: Int
    let unscored_sample_count: Int
    let needs_review_count: Int
    let success_rate: Double
    let timeout_rate: Double
    let mean_duration_ms: Double
    let p50_duration_ms: Double
    let p90_duration_ms: Double
    let p99_duration_ms: Double?
    let insufficient_p99_sample: Bool
    let stddev_duration_ms: Double
    let avg_call_count: Double
    let avg_token_per_call: Double?
    let avg_total_token_per_task: Double?
    let overfetch_rate: Double
    let version_skew_rate: Double
    let avg_claim_rate: Double?
    let avg_slot_rate: Double?
}

func percentile(_ sortedValues: [Int], _ p: Double) -> Double {
    guard !sortedValues.isEmpty else { return 0 }
    let rank = p * Double(sortedValues.count - 1)
    let lower = Int(floor(rank))
    let upper = Int(ceil(rank))
    if lower == upper { return Double(sortedValues[lower]) }
    let weight = rank - Double(lower)
    return Double(sortedValues[lower]) * (1 - weight) + Double(sortedValues[upper]) * weight
}

func mean(_ values: [Int]) -> Double {
    guard !values.isEmpty else { return 0 }
    return Double(values.reduce(0, +)) / Double(values.count)
}

func stddev(_ values: [Int]) -> Double {
    guard values.count > 1 else { return 0 }
    let avg = mean(values)
    let variance = values.map { pow(Double($0) - avg, 2) }.reduce(0, +) / Double(values.count)
    return sqrt(variance)
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    fputs("usage: aggregate-results.swift <records.jsonl> <output.json>\n", stderr)
    exit(1)
}

let inputURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
let decoder = JSONDecoder()
let data = try String(contentsOf: inputURL, encoding: .utf8)
let lines = data.split(separator: "\n")

let records: [Record] = try lines.map { line in
    let lineData = Data(line.utf8)
    return try decoder.decode(Record.self, from: lineData)
}

let grouped = Dictionary(grouping: records) { "\($0.target_id)::\($0.scenario_id)" }

let aggregates: [Aggregate] = grouped.values.map { group in
    let durations = group.map(\.duration_ms).sorted()
    let successCount = group.filter { $0.status == "success" }.count
    let timeoutCount = group.filter { $0.error_category == "timeout" }.count
    let avgToken = group.compactMap(\.avg_token_per_call)
    let totalToken = group.compactMap(\.total_token_per_task)
    let overfetchCount = group.filter(\.overfetch_flag).count
    let versionSkewCount = group.filter { $0.error_category == "version_skew" }.count
    let callCounts = group.map(\.call_count)
    let scoredRows = group.filter { $0.scored_sample ?? true }
    let claimRates = scoredRows.compactMap(\.claim_rate)
    let slotRates = scoredRows.compactMap(\.slot_rate)
    let needsReviewCount = group.filter { $0.needs_review ?? false }.count
    let scoredSampleCount = scoredRows.count
    let unscoredSampleCount = group.count - scoredSampleCount

    return Aggregate(
        target_id: group[0].target_id,
        scenario_id: group[0].scenario_id,
        sample_count: group.count,
        scored_sample_count: scoredSampleCount,
        unscored_sample_count: unscoredSampleCount,
        needs_review_count: needsReviewCount,
        success_rate: Double(successCount) / Double(group.count),
        timeout_rate: Double(timeoutCount) / Double(group.count),
        mean_duration_ms: mean(durations),
        p50_duration_ms: percentile(durations, 0.50),
        p90_duration_ms: percentile(durations, 0.90),
        p99_duration_ms: group.count >= 10 ? percentile(durations, 0.99) : nil,
        insufficient_p99_sample: group.count < 10,
        stddev_duration_ms: stddev(durations),
        avg_call_count: mean(callCounts),
        avg_token_per_call: avgToken.isEmpty ? nil : Double(avgToken.reduce(0, +)) / Double(avgToken.count),
        avg_total_token_per_task: totalToken.isEmpty ? nil : Double(totalToken.reduce(0, +)) / Double(totalToken.count),
        overfetch_rate: Double(overfetchCount) / Double(group.count),
        version_skew_rate: Double(versionSkewCount) / Double(group.count),
        avg_claim_rate: claimRates.isEmpty ? nil : claimRates.reduce(0, +) / Double(claimRates.count),
        avg_slot_rate: slotRates.isEmpty ? nil : slotRates.reduce(0, +) / Double(slotRates.count)
    )
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let output = try encoder.encode(["aggregates": aggregates])
try output.write(to: outputURL)
