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
        // 1. Try environment variable set in CI or by Xcode
        if let workspace = ProcessInfo.processInfo.environment["GITHUB_WORKSPACE"] {
            return URL(fileURLWithPath: workspace)
        }
        if let srcRoot = ProcessInfo.processInfo.environment["SRCROOT"] {
            return URL(fileURLWithPath: srcRoot)
        }
        
        // 2. Fallback to #file traversal (local dev)
        let sourceFile = URL(fileURLWithPath: #file)
        return sourceFile
            .deletingLastPathComponent() // IntegrationTests
            .deletingLastPathComponent() // iDocsTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Root
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
