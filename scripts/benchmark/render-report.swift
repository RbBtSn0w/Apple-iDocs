#!/usr/bin/env swift
import Foundation

struct ScoreFile: Decodable {
    struct TargetScore: Decodable {
        let target_id: String
        let total_score: Double
        let accuracy: Double
        let completeness: Double
        let efficiency: Double
        let token_cost: Double
        let stability: Double
        let diagnosability: Double
        let needs_review_count: Int
        let unscored_sample_count: Int
    }
    let target_scores: [TargetScore]
}

struct FormatFile: Decodable {
    struct Item: Decodable {
        let target_id: String
        let scenario_id: String
        let format_score: Double
    }
    let format_readiness: [Item]
}

struct AggregateFile: Decodable {
    struct Row: Decodable {
        let target_id: String
        let scenario_id: String
        let sample_count: Int
        let scored_sample_count: Int
        let unscored_sample_count: Int
        let needs_review_count: Int
        let avg_claim_rate: Double?
        let avg_slot_rate: Double?
    }
    let aggregates: [Row]
}

struct RecordRow: Decodable {
    let target_id: String
    let scenario_id: String
    let attempt_index: Int
    let sample_class: String
    let needs_review: Bool?
    let assertion_ref: String?
}

let args = CommandLine.arguments
guard args.count >= 6 else {
    fputs("usage: render-report.swift <scores.json> <format.json> <aggregates.json> <records.jsonl> <report.md>\n", stderr)
    exit(1)
}

let scoreData = try Data(contentsOf: URL(fileURLWithPath: args[1]))
let formatData = try Data(contentsOf: URL(fileURLWithPath: args[2]))
let aggregateData = try Data(contentsOf: URL(fileURLWithPath: args[3]))
let recordsText = try String(contentsOfFile: args[4], encoding: .utf8)

let scores = try JSONDecoder().decode(ScoreFile.self, from: scoreData)
let format = try JSONDecoder().decode(FormatFile.self, from: formatData)
let aggregates = try JSONDecoder().decode(AggregateFile.self, from: aggregateData)
let records: [RecordRow] = try recordsText
    .split(separator: "\n")
    .map { try JSONDecoder().decode(RecordRow.self, from: Data($0.utf8)) }

let groupedFormat = Dictionary(grouping: format.format_readiness, by: \.target_id)

func avg(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    return values.reduce(0, +) / Double(values.count)
}

var markdown: [String] = []
markdown.append("# 008 Benchmark Report")
markdown.append("")
markdown.append("## Overall Scores")
markdown.append("")
markdown.append("| Target | Total | Accuracy | Completeness | Efficiency | Token Cost | Stability | Diagnosability | Needs Review | Unscored |")
markdown.append("|--------|-------|----------|--------------|------------|------------|-----------|----------------|--------------|----------|")
for score in scores.target_scores.sorted(by: { $0.total_score > $1.total_score }) {
    markdown.append("| \(score.target_id) | \(String(format: "%.2f", score.total_score)) | \(String(format: "%.2f", score.accuracy)) | \(String(format: "%.2f", score.completeness)) | \(String(format: "%.2f", score.efficiency)) | \(String(format: "%.2f", score.token_cost)) | \(String(format: "%.2f", score.stability)) | \(String(format: "%.2f", score.diagnosability)) | \(score.needs_review_count) | \(score.unscored_sample_count) |")
}

markdown.append("")
markdown.append("## Agent Format Readiness")
markdown.append("")
markdown.append("| Target | Avg Format Score |")
markdown.append("|--------|------------------|")
for score in scores.target_scores {
    let average = avg(groupedFormat[score.target_id, default: []].map(\.format_score))
    markdown.append("| \(score.target_id) | \(String(format: "%.2f", average)) |")
}

markdown.append("")
markdown.append("## Data Integrity Trace")
markdown.append("")
markdown.append("| Target | Scenario | Samples | Scored | Needs Review | Avg Claim Rate | Avg Slot Rate |")
markdown.append("|--------|----------|---------|--------|--------------|----------------|---------------|")
for row in aggregates.aggregates.sorted(by: { "\($0.target_id)::\($0.scenario_id)" < "\($1.target_id)::\($1.scenario_id)" }) {
    let claim = row.avg_claim_rate.map { String(format: "%.2f", $0) } ?? "N/A"
    let slot = row.avg_slot_rate.map { String(format: "%.2f", $0) } ?? "N/A"
    markdown.append("| \(row.target_id) | \(row.scenario_id) | \(row.sample_count) | \(row.scored_sample_count) | \(row.needs_review_count) | \(claim) | \(slot) |")
}

let needsReviewRows = records.filter { $0.needs_review ?? false }
markdown.append("")
markdown.append("## Needs Review Queue")
markdown.append("")
if needsReviewRows.isEmpty {
    markdown.append("No needs-review samples in this run.")
} else {
    markdown.append("| Target | Scenario | Attempt | Sample Class | Assertion Ref |")
    markdown.append("|--------|----------|---------|--------------|---------------|")
    for row in needsReviewRows {
        markdown.append("| \(row.target_id) | \(row.scenario_id) | \(row.attempt_index) | \(row.sample_class) | \(row.assertion_ref ?? "N/A") |")
    }
}

markdown.append("")
markdown.append("## Counterexample Findings")
markdown.append("")
markdown.append("- 错误输入、长内容和噪声高任务必须以相同评分链进入总评。")
markdown.append("- 任何“看似成功但关键字段缺失”的样本应在 slot_rate 中体现并触发扣分或 needs_review。")
markdown.append("- over-fetching 通过主评分惩罚与格式评分双轨体现。")

markdown.append("")
markdown.append("## Fixed Questions")
markdown.append("")
markdown.append("- 哪个目标最适合快速定位信息？见 Overall Scores 与 search 类任务细分。")
markdown.append("- 哪个目标最适合深度阅读？见 fetch/long-content 的格式与完整性组合。")
markdown.append("- 哪个目标最适合低上下文成本问答？见 Token Cost 与 Format Readiness 联合分析。")
markdown.append("- 哪个目标最适合证据溯源？见 Citability 与 assertion/evidence 链接。")

try markdown.joined(separator: "\n").write(to: URL(fileURLWithPath: args[5]), atomically: true, encoding: .utf8)
