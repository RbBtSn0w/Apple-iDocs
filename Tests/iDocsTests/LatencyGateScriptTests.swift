import Foundation
import Testing

@Suite("Latency Gate Script Tests")
struct LatencyGateScriptTests {
    @Test("Latency gate accepts compliant search and fetch samples")
    func latencyGatePassesCompliantSamples() throws {
        let entries: [[String: Any]] = [
            usageEntry(operation: "search", caller: "latency.module", durationMs: 420, resultCount: 1, source: "local"),
            usageEntry(operation: "search", caller: "latency.module", durationMs: 640, resultCount: 1, source: "local"),
            usageEntry(operation: "search", caller: "latency.composite", durationMs: 910, resultCount: 1, source: "local"),
            usageEntry(operation: "search", caller: "latency.composite", durationMs: 1_280, resultCount: 1, source: "apple"),
            usageEntry(operation: "search", caller: "latency.noresult", durationMs: 2_200, resultCount: 0, source: "sosumi"),
            usageEntry(operation: "search", caller: "latency.noresult", durationMs: 2_480, resultCount: 0, source: "sosumi"),
            usageEntry(operation: "fetch", caller: "latency.fetch", durationMs: 180, resultCount: 1, source: "cache", id: "/documentation/swiftui/view"),
            usageEntry(operation: "fetch", caller: "latency.fetch", durationMs: 240, resultCount: 1, source: "local", id: "/documentation/swiftui/view"),
        ]

        let result = try runLatencyGate(with: entries, minSamples: 2)

        #expect(result.exitCode == 0, "Latency gate unexpectedly failed. Output: \(result.output)")
        #expect(result.output.contains("PASS"))
        #expect(result.output.contains("latency.module"))
        #expect(result.output.contains("latency.fetch"))
    }

    @Test("Latency gate rejects slow or invalid samples")
    func latencyGateRejectsSlowOrInvalidSamples() throws {
        let entries: [[String: Any]] = [
            usageEntry(operation: "search", caller: "latency.module", durationMs: 4_500, resultCount: 1, source: "local"),
            usageEntry(operation: "search", caller: "latency.module", durationMs: 9_200, resultCount: 1, source: "local"),
            usageEntry(operation: "search", caller: "latency.composite", durationMs: 900, resultCount: 1, source: "apple"),
            usageEntry(operation: "search", caller: "latency.composite", durationMs: 1_100, resultCount: 1, source: "apple"),
            usageEntry(operation: "search", caller: "latency.noresult", durationMs: 900, resultCount: 0, source: "apple"),
            usageEntry(operation: "search", caller: "latency.noresult", durationMs: 1_100, resultCount: 0, source: "apple"),
            usageEntry(operation: "fetch", caller: "latency.fetch", durationMs: 850, resultCount: 1, source: "apple", id: "/documentation/swiftui/view"),
            usageEntry(operation: "fetch", caller: "latency.fetch", durationMs: 1_250, resultCount: 1, source: "apple", id: "/documentation/swiftui/view"),
        ]

        let result = try runLatencyGate(with: entries, minSamples: 2)

        #expect(result.exitCode != 0, "Latency gate unexpectedly passed. Output: \(result.output)")
        #expect(result.output.contains("FAIL"))
        #expect(result.output.contains("latency.module"))
        #expect(result.output.contains("latency.fetch"))
    }

    private func usageEntry(
        operation: String,
        caller: String,
        durationMs: Double,
        resultCount: Int,
        source: String,
        id: String? = nil
    ) -> [String: Any] {
        var entry: [String: Any] = [
            "operation": operation,
            "caller": caller,
            "status": "success",
            "duration_ms": durationMs,
            "result_count": resultCount,
            "source": source,
            "locale_identifier": "en_US_POSIX",
        ]
        if let id {
            entry["id"] = id
        }
        return entry
    }

    private func runLatencyGate(with entries: [[String: Any]], minSamples: Int) throws -> (exitCode: Int32, output: String) {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let usageLog = temporaryDirectory.appendingPathComponent("usage.jsonl")
        let lines = try entries.map { entry -> String in
            let data = try JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys])
            guard let line = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "LatencyGateScriptTests", code: 1)
            }
            return line
        }
        try (lines.joined(separator: "\n") + "\n").write(to: usageLog, atomically: true, encoding: .utf8)

        let scriptPath = findProjectRoot()
            .appendingPathComponent("scripts/benchmark/evaluate-cli-latency.swift")
            .path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", scriptPath, usageLog.path, "--min-samples", String(minSamples)]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let stderr = String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return (process.terminationStatus, (stdout + stderr).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func findProjectRoot() -> URL {
        var current = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while current.path != "/" {
            if FileManager.default.fileExists(atPath: current.appendingPathComponent("Project.swift").path) {
                return current
            }
            current.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("idocs-latency-gate-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
