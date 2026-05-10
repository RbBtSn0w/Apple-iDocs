import Foundation

enum CLIVersion {
    private static let sidecarFilename = "idocs.version"
    private static let fallbackVersion = "0.0.0-dev"

    private struct PackageManifest: Decodable {
        let version: String
    }

    static func current(
        executableURL: URL? = defaultExecutableURL(),
        currentDirectoryURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> String {
        if let version = normalizedVersion(environment["IDOCS_CLI_VERSION"]) {
            return version
        }

        if let executableURL,
           let version = sidecarVersion(for: executableURL, fileManager: fileManager) {
            return version
        }

        if let version = packageManifestVersion(searchingFrom: currentDirectoryURL, fileManager: fileManager) {
            return version
        }

        return fallbackVersion
    }

    private static func defaultExecutableURL() -> URL? {
        if let executableURL = Bundle.main.executableURL {
            return executableURL
        }

        guard let executablePath = CommandLine.arguments.first, !executablePath.isEmpty else {
            return nil
        }

        if executablePath.hasPrefix("/") {
            return URL(fileURLWithPath: executablePath)
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent(executablePath)
    }

    private static func sidecarVersion(for executableURL: URL, fileManager: FileManager) -> String? {
        let sidecarURL = executableURL
            .deletingLastPathComponent()
            .appendingPathComponent(sidecarFilename)
        return readPlainVersion(at: sidecarURL, fileManager: fileManager)
    }

    private static func packageManifestVersion(searchingFrom startURL: URL, fileManager: FileManager) -> String? {
        var current = startURL.hasDirectoryPath ? startURL : startURL.deletingLastPathComponent()

        while true {
            let packageURL = current
                .appendingPathComponent("npm", isDirectory: true)
                .appendingPathComponent("package.json")
            if let version = readPackageVersion(at: packageURL, fileManager: fileManager) {
                return version
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                return nil
            }
            current = parent
        }
    }

    private static func readPlainVersion(at url: URL, fileManager: FileManager) -> String? {
        guard fileManager.fileExists(atPath: url.path),
              let value = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return normalizedVersion(value)
    }

    private static func readPackageVersion(at url: URL, fileManager: FileManager) -> String? {
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(PackageManifest.self, from: data) else {
            return nil
        }
        return normalizedVersion(manifest.version)
    }

    private static func normalizedVersion(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
