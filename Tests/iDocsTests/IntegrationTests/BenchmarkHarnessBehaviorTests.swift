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
        let env = ProcessInfo.processInfo.environment
        
        // 1. Primary: Explicit project root (best for CI)
        if let projectRoot = env["IDOCS_PROJECT_ROOT"], !projectRoot.isEmpty {
            return URL(fileURLWithPath: projectRoot)
        }
        
        // 2. Secondary: Standard workspace env
        if let workspace = env["GITHUB_WORKSPACE"], !workspace.isEmpty {
            return URL(fileURLWithPath: workspace)
        }
        
        // 3. Search upwards for the repository marker, avoiding DerivedData
        var current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while current.path != "/" {
            if current.path.contains("DerivedData") || current.path.contains(".build") {
                current = current.deletingLastPathComponent()
                continue
            }
            
            let marker = current.appendingPathComponent("Project.swift")
            if FileManager.default.fileExists(atPath: marker.path) {
                return current
            }
            current = current.deletingLastPathComponent()
        }
        
        // 4. Fallback to #file traversal
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
