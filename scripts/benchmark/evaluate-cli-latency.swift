#!/usr/bin/env swift

import Foundation

struct UsageRecord: Decodable {
    let operation: String
    let caller: String?
    let status: String
    let durationMs: Double
    let resultCount: Int
    let source: String?

    enum CodingKeys: String, CodingKey {
        case operation
        case caller
        case status
        case durationMs = "duration_ms"
        case resultCount = "result_count"
        case source
    }
}

struct Config {
    let usageLogPath: String
    var minSamples = 5
    var moduleP50Ms = 3_000.0
    var moduleP95Ms = 8_000.0
    var compositeP95Ms = 15_000.0
    var noResultP95Ms = 15_000.0
    var fetchP95Ms = 1_000.0
}

struct ScenarioDefinition {
    let name: String
    let operation: String
    let callerPrefix: String
    let excludedCallerPrefixes: [String]
    let p50LimitMs: Double?
    let p95LimitMs: Double
    let requiredSources: Set<String>?
    let requireZeroResults: Bool

    func matches(_ record: UsageRecord) -> Bool {
        guard record.operation == operation, let caller = record.caller else {
            return false
        }
        guard caller.hasPrefix(callerPrefix) else {
            return false
        }
        return !excludedCallerPrefixes.contains(where: { caller.hasPrefix($0) })
    }
}

struct ScenarioResult {
    let definition: ScenarioDefinition
    let sampleCount: Int
    let p50Ms: Double
    let p95Ms: Double
    let reasons: [String]

    var passed: Bool { reasons.isEmpty }
}

func percentile(_ sortedValues: [Double], _ p: Double) -> Double {
    guard !sortedValues.isEmpty else { return 0 }
    let rank = p * Double(sortedValues.count - 1)
    let lower = Int(floor(rank))
    let upper = Int(ceil(rank))
    if lower == upper { return sortedValues[lower] }
    let weight = rank - Double(lower)
    return sortedValues[lower] * (1 - weight) + sortedValues[upper] * weight
}

func formatMillis(_ value: Double) -> String {
    String(format: "%.2f", value)
}

func parseConfig(arguments: [String]) throws -> Config {
    guard arguments.count >= 2 else {
        throw ValidationError("usage: evaluate-cli-latency.swift <usage.jsonl> [--min-samples N] [--module-p50-ms N] [--module-p95-ms N] [--composite-p95-ms N] [--noresult-p95-ms N] [--fetch-p95-ms N]")
    }

    var config = Config(usageLogPath: arguments[1])
    var index = 2
    while index < arguments.count {
        let argument = arguments[index]
        func readValue() throws -> String {
            let valueIndex = index + 1
            guard valueIndex < arguments.count else {
                throw ValidationError("Missing value for \(argument)")
            }
            index += 2
            return arguments[valueIndex]
        }

        switch argument {
        case "--min-samples":
            config.minSamples = try parseInt(try readValue(), flag: argument)
        case "--module-p50-ms":
            config.moduleP50Ms = try parseDouble(try readValue(), flag: argument)
        case "--module-p95-ms":
            config.moduleP95Ms = try parseDouble(try readValue(), flag: argument)
        case "--composite-p95-ms":
            config.compositeP95Ms = try parseDouble(try readValue(), flag: argument)
        case "--noresult-p95-ms":
            config.noResultP95Ms = try parseDouble(try readValue(), flag: argument)
        case "--fetch-p95-ms":
            config.fetchP95Ms = try parseDouble(try readValue(), flag: argument)
        default:
            throw ValidationError("Unknown argument: \(argument)")
        }
    }

    guard config.minSamples >= 1 else {
        throw ValidationError("--min-samples must be >= 1")
    }
    return config
}

func parseInt(_ rawValue: String, flag: String) throws -> Int {
    guard let value = Int(rawValue) else {
        throw ValidationError("Invalid integer for \(flag): \(rawValue)")
    }
    return value
}

func parseDouble(_ rawValue: String, flag: String) throws -> Double {
    guard let value = Double(rawValue) else {
        throw ValidationError("Invalid number for \(flag): \(rawValue)")
    }
    return value
}

func loadRecords(from path: String) throws -> [UsageRecord] {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw ValidationError("Usage log does not exist: \(url.path)")
    }

    let data = try String(contentsOf: url, encoding: .utf8)
    let decoder = JSONDecoder()
    return try data
        .split(separator: "\n")
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .enumerated()
        .map { index, rawLine in
            do {
                return try decoder.decode(UsageRecord.self, from: Data(rawLine.utf8))
            } catch {
                throw ValidationError("Invalid JSONL entry at line \(index + 1): \(error)")
            }
        }
}

func evaluate(records: [UsageRecord], config: Config) -> [ScenarioResult] {
    let definitions = [
        ScenarioDefinition(
            name: "latency.module",
            operation: "search",
            callerPrefix: "latency.module",
            excludedCallerPrefixes: [],
            p50LimitMs: config.moduleP50Ms,
            p95LimitMs: config.moduleP95Ms,
            requiredSources: ["local"],
            requireZeroResults: false
        ),
        ScenarioDefinition(
            name: "latency.composite",
            operation: "search",
            callerPrefix: "latency.composite",
            excludedCallerPrefixes: [],
            p50LimitMs: nil,
            p95LimitMs: config.compositeP95Ms,
            requiredSources: nil,
            requireZeroResults: false
        ),
        ScenarioDefinition(
            name: "latency.noresult",
            operation: "search",
            callerPrefix: "latency.noresult",
            excludedCallerPrefixes: [],
            p50LimitMs: nil,
            p95LimitMs: config.noResultP95Ms,
            requiredSources: nil,
            requireZeroResults: true
        ),
        ScenarioDefinition(
            name: "latency.fetch",
            operation: "fetch",
            callerPrefix: "latency.fetch",
            excludedCallerPrefixes: ["latency.fetch.warmup"],
            p50LimitMs: nil,
            p95LimitMs: config.fetchP95Ms,
            requiredSources: ["cache", "local"],
            requireZeroResults: false
        ),
    ]

    return definitions.map { definition in
        let matching = records.filter(definition.matches)
        let durations = matching.map(\.durationMs).sorted()
        var reasons: [String] = []

        if matching.count < config.minSamples {
            reasons.append("expected at least \(config.minSamples) sample(s), found \(matching.count)")
        }

        let failedStatuses = matching.filter { $0.status != "success" }
        if !failedStatuses.isEmpty {
            reasons.append("found \(failedStatuses.count) non-success sample(s)")
        }

        if let requiredSources = definition.requiredSources {
            let invalidSources = matching.compactMap { record -> String? in
                guard let source = record.source else { return "<missing>" }
                return requiredSources.contains(source) ? nil : source
            }
            if !invalidSources.isEmpty {
                let sourceList = invalidSources.sorted().joined(separator: ", ")
                reasons.append("expected sources within [\(requiredSources.sorted().joined(separator: ", "))], found [\(sourceList)]")
            }
        }

        if definition.requireZeroResults {
            let invalidCounts = matching.filter { $0.resultCount != 0 }
            if !invalidCounts.isEmpty {
                reasons.append("expected zero-result samples, found \(invalidCounts.count) non-zero sample(s)")
            }
        }

        let p50 = percentile(durations, 0.50)
        let p95 = percentile(durations, 0.95)

        if let p50Limit = definition.p50LimitMs, !durations.isEmpty, p50 > p50Limit {
            reasons.append("p50 \(formatMillis(p50))ms exceeded \(formatMillis(p50Limit))ms")
        }
        if !durations.isEmpty, p95 > definition.p95LimitMs {
            reasons.append("p95 \(formatMillis(p95))ms exceeded \(formatMillis(definition.p95LimitMs))ms")
        }

        return ScenarioResult(
            definition: definition,
            sampleCount: matching.count,
            p50Ms: p50,
            p95Ms: p95,
            reasons: reasons
        )
    }
}

func render(results: [ScenarioResult]) -> String {
    let passed = results.allSatisfy(\.passed)
    var lines = [passed ? "PASS cli latency gate" : "FAIL cli latency gate"]

    for result in results {
        let status = result.passed ? "PASS" : "FAIL"
        lines.append(
            "- [\(status)] \(result.definition.name): samples=\(result.sampleCount) p50=\(formatMillis(result.p50Ms))ms p95=\(formatMillis(result.p95Ms))ms"
        )
        for reason in result.reasons {
            lines.append("  reason: \(reason)")
        }
    }

    return lines.joined(separator: "\n")
}

struct ValidationError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

do {
    let config = try parseConfig(arguments: CommandLine.arguments)
    let records = try loadRecords(from: config.usageLogPath)
    let results = evaluate(records: records, config: config)
    let output = render(results: results)
    print(output)
    exit(results.allSatisfy(\.passed) ? 0 : 1)
} catch {
    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    fputs("Error: \(message)\n", stderr)
    exit(1)
}
