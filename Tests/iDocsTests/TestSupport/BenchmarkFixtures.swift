import Foundation

enum BenchmarkFixtures {
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
        repositoryRoot().appendingPathComponent(relativePath)
    }

    static func fixtureData(_ relativePath: String) throws -> Data {
        try Data(contentsOf: fixtureURL(relativePath))
    }

    static func fixtureJSON(_ relativePath: String) throws -> Any {
        let data = try fixtureData(relativePath)
        return try JSONSerialization.jsonObject(with: data)
    }
}
