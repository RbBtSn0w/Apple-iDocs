import Foundation
import Testing

@Suite("Benchmark Harness Behavior Tests")
struct BenchmarkHarnessBehaviorTests {
    @Test("idocs target probe should return success JSON")
    func idocsProbe() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "./scripts/benchmark/target-idocs-cli.sh --probe"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(process.terminationStatus == 0)
        let jsonData = try #require(output.data(using: .utf8))
        let payload = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        #expect(payload?["status"] as? String == "success")
    }
}
