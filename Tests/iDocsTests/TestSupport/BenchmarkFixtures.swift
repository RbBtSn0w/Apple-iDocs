import Foundation

enum BenchmarkFixtures {
    private final class BundleToken {}

    static func repositoryRoot(file: StaticString = #filePath) -> URL {
        var url = URL(fileURLWithPath: "\(file)")
        while url.pathComponents.count > 1 {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Project.swift").path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    static func fixtureURL(_ relativePath: String) -> URL {
        let fileName = URL(fileURLWithPath: relativePath).lastPathComponent
        if let bundledURL = Bundle(for: BundleToken.self).url(forResource: fileName, withExtension: nil) {
            return bundledURL
        }
        return repositoryRoot().appendingPathComponent(relativePath)
    }

    static func fixtureData(_ relativePath: String) throws -> Data {
        try Data(contentsOf: fixtureURL(relativePath))
    }

    static func fixtureJSON(_ relativePath: String) throws -> Any {
        let data = try fixtureData(relativePath)
        return try JSONSerialization.jsonObject(with: data)
    }
}
