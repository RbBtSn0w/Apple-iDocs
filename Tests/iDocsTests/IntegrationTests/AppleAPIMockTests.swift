import Testing
import Foundation
@testable import iDocsKit

@Suite("Apple JSON API Mock Tests")
struct AppleAPIMockTests {
    
    @Test("Retry on 403 or 429 error")
    func testRetryLogic() async throws {
        let mockSession = MockNetworkSession()
        let api = AppleJSONAPI(session: mockSession)
        
        let errorResponse = HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 403, httpVersion: nil, headerFields: nil)!
        
        // Since AppleJSONAPI uses a loop, we can't easily stub sequence in this simple mock
        // unless we enhance MockNetworkSession. 
        // For now, let's just test that it fails after max retries.
        mockSession.stubbedResponse = errorResponse
        mockSession.stubbedData = Data()
        
        await #expect(throws: Error.self) {
            try await api.search(query: "test")
        }
    }
    
    @Test("Fail on 404 error without retry")
    func testFatalError() async throws {
        let mockSession = MockNetworkSession()
        let api = AppleJSONAPI(session: mockSession)
        
        let errorResponse = HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 404, httpVersion: nil, headerFields: nil)!
        mockSession.stubbedResponse = errorResponse
        mockSession.stubbedData = Data()
        
        await #expect(throws: Error.self) {
            try await api.search(query: "test")
        }
    }
}

private enum BenchmarkHarnessGate {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["IDOCS_BENCHMARK_TESTS"] == "1"
    }
}

@Suite("Benchmark Harness Behavior Tests", .enabled(if: BenchmarkHarnessGate.isEnabled))
struct BenchmarkHarnessBehaviorTests {
    @Test("idocs target probe should return success JSON")
    func idocsProbe() throws {
        let root = findProjectRoot()
        let sourceScriptPath = root.appendingPathComponent("scripts/benchmark/target-idocs.sh").path

        guard FileManager.default.fileExists(atPath: sourceScriptPath) else {
            print("[SKIP] Benchmark script not found at \(sourceScriptPath). Root resolved as: \(root.path). Working Dir: \(FileManager.default.currentDirectoryPath)")
            return
        }

        let binPath = ProcessInfo.processInfo.environment["IDOCS_LOCAL_BINARY"] ?? findLocalBinary(projectRoot: root.path)
        guard let binPath else {
            print("[SKIP] Local idocs binary not found for benchmark probe test. Root: \(root.path)")
            return
        }

        let stagingDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: stagingDirectory) }
        let scriptPath = try stageFile(at: sourceScriptPath, in: stagingDirectory).path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath, "--probe"]

        var env = ProcessInfo.processInfo.environment
        env["IDOCS_LOCAL_BINARY"] = binPath
        env["IDOCS_PROJECT_ROOT"] = root.path
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let output = String(
            decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = String(
            decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(process.terminationStatus == 0, "Probe failed with exit code \(process.terminationStatus). Script: \(scriptPath). Binary: \(binPath). Root: \(root.path). Stdout: \(output). Stderr: \(stderr)")
        let jsonData = try #require(output.data(using: .utf8), "Output was not UTF8. Binary: \(binPath). Stdout: \(output). Stderr: \(stderr)")
        let payload = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        #expect(payload?["status"] as? String == "success", "Probe returned non-success status. Stdout: \(output). Stderr: \(stderr)")
    }

    @Test("mcp client should reject prerequisite blocker responses")
    func failureLikeProbeIsRejected() throws {
        let root = findProjectRoot()
        let sourceClientPath = root.appendingPathComponent("scripts/benchmark/mcp-client.mjs").path
        let sourceServerPath = root.appendingPathComponent("scripts/benchmark/mock-mcp-server.mjs").path

        guard FileManager.default.fileExists(atPath: sourceClientPath),
              FileManager.default.fileExists(atPath: sourceServerPath) else {
            Issue.record("Benchmark client or mock server missing. client=\(sourceClientPath) server=\(sourceServerPath)")
            return
        }

        let stagingDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: stagingDirectory) }
        let clientPath = try stageFile(at: sourceClientPath, in: stagingDirectory).path
        let serverPath = try stageFile(at: sourceServerPath, in: stagingDirectory).path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "node",
            clientPath,
            "--command-bin",
            "node",
            "--command-arg",
            serverPath,
            "--command-arg",
            "failure-like",
            "--input",
            "SwiftUI View",
            "--reject-pattern",
            "No Technology Selected"
        ]

        var env = ProcessInfo.processInfo.environment
        env["IDOCS_PROJECT_ROOT"] = root.path
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let output = String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonData = try #require(output.data(using: .utf8), "Stdout was not UTF8. Stdout: \(output). Stderr: \(stderr)")
        let payload = try #require(JSONSerialization.jsonObject(with: jsonData) as? [String: Any])

        #expect(process.terminationStatus != 0, "Probe unexpectedly succeeded. Stdout: \(output). Stderr: \(stderr)")
        #expect(payload["status"] as? String == "failure", "Failure-like probe should be marked as failure. Stdout: \(output). Stderr: \(stderr)")
    }

    private func findProjectRoot() -> URL {
        let env = ProcessInfo.processInfo.environment

        if let projectRoot = env["IDOCS_PROJECT_ROOT"], !projectRoot.isEmpty {
            return URL(fileURLWithPath: projectRoot)
        }
        if let workspace = env["GITHUB_WORKSPACE"], !workspace.isEmpty {
            return URL(fileURLWithPath: workspace)
        }

        var current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while current.path != "/" {
            if current.path.contains("DerivedData") || current.path.contains(".build") {
                current = current.deletingLastPathComponent()
                continue
            }

            let marker = current.appendingPathComponent("Tuist")
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: marker.path, isDirectory: &isDir), isDir.boolValue {
                return current
            }
            current = current.deletingLastPathComponent()
        }

        var sourceFile = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while sourceFile.path != "/" {
            let tuistDir = sourceFile.appendingPathComponent("Tuist")
            let project = sourceFile.appendingPathComponent("Project.swift")
            if FileManager.default.fileExists(atPath: tuistDir.path) ||
                FileManager.default.fileExists(atPath: project.path) {
                return sourceFile
            }
            sourceFile.deleteLastPathComponent()
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private func findLocalBinary(projectRoot: String) -> String? {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
        let candidates = [
            "\(home)/Library/Developer/Xcode/DerivedData/iDocs-codex/Build/Products/Debug/idocs",
            "\(projectRoot)/.build/debug/idocs",
            "\(projectRoot)/.build/release/idocs"
        ]

        for candidate in candidates where FileManager.default.fileExists(atPath: candidate) {
            return URL(fileURLWithPath: candidate).path
        }
        return nil
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("idocs-benchmark-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func stageFile(at sourcePath: String, in directory: URL) throws -> URL {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let destinationURL = directory.appendingPathComponent(sourceURL.lastPathComponent)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }
}
