import Foundation
import Testing

@Suite("Benchmark Harness Behavior Tests")
struct BenchmarkHarnessBehaviorTests {
    @Test("idocs target probe should return success JSON")
    func idocsProbe() throws {
        let root = findProjectRoot()
        let scriptPath = root.appendingPathComponent("scripts/benchmark/target-idocs-cli.sh").path

        // Resolve idocs binary to avoid tuist run overhead/instability
        let binPath = ProcessInfo.processInfo.environment["IDOCS_LOCAL_BINARY"] ?? findLocalBinary(projectRoot: root.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath, "--probe"]
        process.currentDirectoryURL = root

        var env = ProcessInfo.processInfo.environment
        if let binPath = binPath {
            env["IDOCS_LOCAL_BINARY"] = binPath
        }
        process.environment = env

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(process.terminationStatus == 0, "Probe failed with exit code \(process.terminationStatus). Script: \(scriptPath). Binary: \(binPath ?? "nil"). Working Dir: \(FileManager.default.currentDirectoryPath). Output: \(output)")
        let jsonData = try #require(output.data(using: .utf8), "Output was not UTF8. Binary: \(binPath ?? "nil"). Output: \(output)")
        let payload = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        #expect(payload?["status"] as? String == "success", "Probe returned non-success status. Payload: \(output)")
    }

    private func findProjectRoot() -> URL {
        var current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while current.path != "/" {
            if FileManager.default.fileExists(atPath: current.appendingPathComponent("Project.swift").path) {
                return current
            }
            current = current.deletingLastPathComponent()
        }
        // Fallback to current dir if not found
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private func findLocalBinary(projectRoot: String) -> String? {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
        let candidates = [
            "\(home)/Library/Developer/Xcode/DerivedData/iDocs-codex/Build/Products/Debug/idocs",
            "\(projectRoot)/.build/debug/idocs",
            "\(projectRoot)/.build/release/idocs"
        ]
        
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate) {
                return URL(fileURLWithPath: candidate).path
            }
        }
        return nil
    }
}
