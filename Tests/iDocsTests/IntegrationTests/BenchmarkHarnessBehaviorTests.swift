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

        #expect(process.terminationStatus == 0, "Probe failed with exit code \(process.terminationStatus). Script: \(scriptPath). Binary: \(binPath ?? "nil"). Root: \(root.path). Working Dir: \(FileManager.default.currentDirectoryPath). Output: \(output)")
        let jsonData = try #require(output.data(using: .utf8), "Output was not UTF8. Binary: \(binPath ?? "nil"). Output: \(output)")
        let payload = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        #expect(payload?["status"] as? String == "success", "Probe returned non-success status. Payload: \(output)")
    }

    private func findProjectRoot() -> URL {
        // 1. Try environment variable
        if let workspace = ProcessInfo.processInfo.environment["GITHUB_WORKSPACE"] {
            return URL(fileURLWithPath: workspace)
        }
        
        // 2. Search upwards for the scripts directory (most reliable)
        var current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while current.path != "/" {
            let scriptsDir = current.appendingPathComponent("scripts/benchmark")
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: scriptsDir.path, isDirectory: &isDir), isDir.boolValue {
                return current
            }
            current = current.deletingLastPathComponent()
        }
        
        // 3. Fallback to #file traversal
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
