#!/usr/bin/env swift
import Foundation

struct Record: Decodable {
    let target_id: String
    let scenario_id: String
    let format_extractability: Int
    let format_density: Int
    let format_task_fit: Int
    let format_noise: Int
    let format_citability: Int
}

struct Output: Encodable {
    let target_id: String
    let scenario_id: String
    let format_score: Double
}

func normalized(_ value: Int) -> Double {
    switch value {
    case 5: return 1
    case 3: return 0.6
    default: return 0.2
    }
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    fputs("usage: evaluate-format-readiness.swift <records.jsonl> <output.json>\n", stderr)
    exit(1)
}

let lines = try String(contentsOfFile: args[1], encoding: .utf8).split(separator: "\n")
let decoder = JSONDecoder()
let rows: [Output] = try lines.map { line in
    let record = try decoder.decode(Record.self, from: Data(line.utf8))
    let score =
        normalized(record.format_extractability) * 30 +
        normalized(record.format_density) * 25 +
        normalized(record.format_task_fit) * 20 +
        normalized(record.format_noise) * 15 +
        normalized(record.format_citability) * 10
    return Output(target_id: record.target_id, scenario_id: record.scenario_id, format_score: score)
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(["format_readiness": rows]).write(to: URL(fileURLWithPath: args[2]))
