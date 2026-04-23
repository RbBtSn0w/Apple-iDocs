import Foundation

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

        do {
            try process.run()
            let start = Date()

            while process.isRunning && Date().timeIntervalSince(start) < timeoutSeconds {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }

            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
                return []
            }

            guard process.terminationStatus == 0 else { return [] }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            return output
                .split(separator: "\n")
                .map { URL(fileURLWithPath: String($0)) }
        } catch {
            return []
        }
    }
}
