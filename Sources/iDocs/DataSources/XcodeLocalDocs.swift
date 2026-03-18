import Foundation
import Logging

public struct XcodeLocalDocs {
    private let logger = Logger(label: "com.snow.idocs-xcode-docs")
    private let fileManager: any FileSystem
    private let searchProvider: any SearchProvider
    
    public let cacheDirectory: URL
    
    public init(fileManager: any FileSystem = FileManager.default, 
                searchProvider: any SearchProvider = SpotlightSearchProvider()) {
        self.fileManager = fileManager
        self.searchProvider = searchProvider
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.cacheDirectory = home.appendingPathComponent("Library/Developer/Xcode/DocumentationCache")
    }
    
    public func listAvailableSDKs() async throws -> [XcodeLocalDocInfo] {
        guard fileManager.fileExists(atPath: cacheDirectory.path) else {
            logger.warning("Xcode DocumentationCache not found at \(cacheDirectory.path)")
            return []
        }
        
        let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [URLResourceKey.contentModificationDateKey], options: [])
        
        var sdks: [XcodeLocalDocInfo] = []
        for url in contents where url.hasDirectoryPath {
            // Directory names are typically like "iOS 18.0" or contain platform info
            let name = url.lastPathComponent
            let modificationDate = (try? url.resourceValues(forKeys: [URLResourceKey.contentModificationDateKey]).contentModificationDate) ?? Date()
            
            sdks.append(XcodeLocalDocInfo(
                sdkVersion: name,
                platform: guessPlatform(from: name),
                cachePath: url,
                hasIndex: fileManager.fileExists(atPath: url.appendingPathComponent("data.mdb").path),
                lastModified: modificationDate
            ))
        }
        return sdks
    }
    
    public func search(query: String) async throws -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let sdks = try await listAvailableSDKs()
        logger.info("Searching \(sdks.count) local SDK documentations for: \(trimmed)")

        var results: [SearchResult] = []

        // Preferred path: delegate lookup to injected search provider (Spotlight/Mock/etc.)
        if let urls = try? await searchProvider.search(query: trimmed), !urls.isEmpty {
            results.append(contentsOf: urls.prefix(50).map { fileURL in
                let fileName = fileURL.deletingPathExtension().lastPathComponent
                return SearchResult(
                    title: fileName,
                    abstract: "Matched in local Xcode documentation index.",
                    path: "/documentation/\(fileName)",
                    kind: .overview,
                    source: .local
                )
            })
        }

        // Fallback path: lightweight scan under local documentation roots.
        if results.isEmpty {
            let needle = trimmed.lowercased()
            for sdk in sdks {
                let docsDir = sdk.cachePath.appendingPathComponent("documentation")
                guard fileManager.fileExists(atPath: docsDir.path) else { continue }
                let entries = (try? fileManager.contentsOfDirectory(at: docsDir, includingPropertiesForKeys: nil, options: [])) ?? []
                for entry in entries where entry.hasDirectoryPath {
                    let module = entry.lastPathComponent
                    guard module.lowercased().contains(needle) else { continue }
                    results.append(
                        SearchResult(
                            title: module,
                            abstract: "Matched module name in local Xcode documentation.",
                            path: "/documentation/\(module)",
                            kind: .framework,
                            source: .local
                        )
                    )
                    if results.count >= 50 { return results }
                }
            }
        }

        return results
    }
    
    public func fetchDoc(path: String) async throws -> DocCContent? {
        let sdks = try await listAvailableSDKs()
        for sdk in sdks {
            let docPath = sdk.cachePath.appendingPathComponent("documentation/\(path).json")
            if fileManager.fileExists(atPath: docPath.path) {
                logger.info("Found local documentation at \(docPath.path)")
                
                // Keep mmap behavior for real FileManager, but honor injected FileSystem for tests/mocks.
                let data: Data
                if fileManager is FileManager {
                    data = try Data(contentsOf: docPath, options: .mappedIfSafe)
                } else {
                    data = try fileManager.read(from: docPath)
                }
                return try JSONDecoder().decode(DocCContent.self, from: data)
            }
        }
        return nil
    }
    
    private func guessPlatform(from name: String) -> String {
        if name.contains("iOS") { return "iOS" }
        if name.contains("macOS") { return "macOS" }
        if name.contains("watchOS") { return "watchOS" }
        if name.contains("tvOS") { return "tvOS" }
        if name.contains("visionOS") { return "visionOS" }
        return "Unknown"
    }
}

// MARK: - Entity Definition

public struct XcodeLocalDocInfo: Codable, Sendable {
    public let sdkVersion: String
    public let platform: String
    public let cachePath: URL
    public let hasIndex: Bool
    public let lastModified: Date
}
