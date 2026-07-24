import Foundation
import iDocsTelemetry

public final class SpotlightSearchProvider: SearchProvider, @unchecked Sendable {
    private let timeoutSeconds: TimeInterval

    public init(timeoutSeconds: TimeInterval = 2.0) {
        self.timeoutSeconds = timeoutSeconds
    }
    
    public func search(query: String) async throws -> [URL] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = [
            "kMDItemPath == \"*/Library/Developer/Xcode/DocumentationCache/*\"c && kMDItemFSName == \"*\(trimmed)*\"c"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        return await iDocsTelemetry.withProcessSpan(
            executableName: "mdfind",
            arguments: ["mdfind"] + (process.arguments ?? [])
        ) {
            do {
                try process.run()
                iDocsTelemetry.setAttributes([
                    "process.pid": .int(Int(process.processIdentifier))
                ])
                let start = Date()

                while process.isRunning && Date().timeIntervalSince(start) < timeoutSeconds {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }

                if process.isRunning {
                    process.terminate()
                    process.waitUntilExit()
                    iDocsTelemetry.setExitCode(process.terminationStatus)
                    iDocsTelemetry.markFailure(
                        TelemetryFailureDescriptor(
                            errorType: "timeout",
                            category: "dependency",
                            slug: "idocs.process.mdfind.timeout",
                            expected: true,
                            exceptionType: "ProcessTimeout",
                            safeMessage: "Spotlight search timed out."
                        )
                    )
                    return []
                }

                iDocsTelemetry.setExitCode(process.terminationStatus)
                guard process.terminationStatus == 0 else {
                    iDocsTelemetry.markFailure(
                        TelemetryFailureDescriptor(
                            errorType: "subprocess_failed",
                            category: "dependency",
                            slug: "idocs.process.mdfind.failed",
                            expected: true,
                            exceptionType: "ProcessExitCode",
                            safeMessage: "Spotlight search failed."
                        )
                    )
                    return []
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8) else { return [] }
                return output
                    .split(separator: "\n")
                    .map { URL(fileURLWithPath: String($0)) }
            } catch {
                iDocsTelemetry.markFailure(
                    TelemetryFailureDescriptor(
                        errorType: "subprocess_failed",
                        category: "dependency",
                        slug: "idocs.process.mdfind.start_failed",
                        expected: true,
                        exceptionType: String(describing: Swift.type(of: error)),
                        safeMessage: "Spotlight search failed to start."
                    )
                )
                return []
            }
        }
    }
}
