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
            let modificationDate = try url.resourceValues(forKeys: [URLResourceKey.contentModificationDateKey]).contentModificationDate ?? Date()
            
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
        // Phase 5 implementation: Simplified local search
        // Future: Integration with LMDB index or Spotlight
        let sdks = try await listAvailableSDKs()
        logger.info("Searching \(sdks.count) local SDK documentations for: \(query)")
        
        // This is a placeholder for actual local index searching
        return []
    }
    
    public func fetchDoc(path: String) async throws -> DocCContent? {
        let sdks = try await listAvailableSDKs()
        for sdk in sdks {
            let docPath = sdk.cachePath.appendingPathComponent("documentation/\(path).json")
            if fileManager.fileExists(atPath: docPath.path) {
                logger.info("Found local documentation at \(docPath.path)")
                
                // Use mmap via Data(contentsOf:options:)
                let data = try Data(contentsOf: docPath, options: .mappedIfSafe)
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
