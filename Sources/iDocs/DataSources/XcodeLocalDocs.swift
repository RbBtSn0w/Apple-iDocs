import Foundation
import Logging

public struct XcodeLocalDocs {
    private let logger = Logger(label: "com.snow.idocs-xcode-docs")
    private let fileManager: any FileSystem
    private let searchProvider: any SearchProvider
    
    public let cacheDirectory: URL
    
    public init(fileManager: any FileSystem = FileManager.default, 
                searchProvider: any SearchProvider = SpotlightSearchProvider(),
                cacheDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.searchProvider = searchProvider
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.cacheDirectory = home.appendingPathComponent("Library/Developer/Xcode/DocumentationCache")
        }
    }
    
    public func listAvailableSDKs() async throws -> [XcodeLocalDocInfo] {
        guard fileManager.fileExists(atPath: cacheDirectory.path) else {
            logger.warning("Xcode DocumentationCache not found at \(cacheDirectory.path)")
            return []
        }
        
        let contents = try discoverSDKDirectories(from: cacheDirectory, depth: 2)
        
        var sdks: [XcodeLocalDocInfo] = []
        for url in contents where url.hasDirectoryPath {
            // Directory names are typically like "iOS 18.0" or contain platform info
            let name = url.lastPathComponent
            let modificationDate = (try? url.resourceValues(forKeys: [URLResourceKey.contentModificationDateKey]).contentModificationDate) ?? Date()
            let hasModernIndex = fileManager.fileExists(atPath: url.appendingPathComponent("DeveloperDocumentation.index").path)
            let hasLegacyIndex = fileManager.fileExists(atPath: url.appendingPathComponent("data.mdb").path)
            let hasDocumentationRoot = fileManager.fileExists(atPath: url.appendingPathComponent("documentation").path)
            
            sdks.append(XcodeLocalDocInfo(
                sdkVersion: name,
                platform: guessPlatform(from: name),
                cachePath: url,
                hasIndex: hasModernIndex || hasLegacyIndex || hasDocumentationRoot,
                lastModified: modificationDate
            ))
        }
        return sdks
    }

    private func discoverSDKDirectories(from root: URL, depth: Int) throws -> [URL] {
        guard depth >= 0 else { return [] }

        let contents = try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [URLResourceKey.contentModificationDateKey],
            options: []
        )

        var discovered: [URL] = []
        for entry in contents where entry.hasDirectoryPath {
            let hasModernIndex = fileManager.fileExists(atPath: entry.appendingPathComponent("DeveloperDocumentation.index").path)
            let hasLegacyIndex = fileManager.fileExists(atPath: entry.appendingPathComponent("data.mdb").path)
            let hasDocumentationRoot = fileManager.fileExists(atPath: entry.appendingPathComponent("documentation").path)

            if hasModernIndex || hasLegacyIndex || hasDocumentationRoot {
                discovered.append(entry)
                continue
            }

            if depth > 0 {
                discovered.append(contentsOf: try discoverSDKDirectories(from: entry, depth: depth - 1))
            }
        }

        return discovered
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

        let indexResults = searchIndexStores(query: trimmed, sdks: sdks)
        if !indexResults.isEmpty {
            return indexResults
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

    private func searchIndexStores(query: String, sdks: [XcodeLocalDocInfo]) -> [SearchResult] {
        guard isLikelyModuleQuery(query) else { return [] }

        var seenTitles = Set<String>()
        var results: [SearchResult] = []

        for sdk in sdks where sdk.hasIndex {
            for storeURL in indexStoreURLs(for: sdk.cachePath) {
                guard let data = try? fileManager.read(from: storeURL) else { continue }
                let printableStrings = extractPrintableStrings(from: data)
                for match in printableStrings where match.caseInsensitiveCompare(query) == .orderedSame {
                    let normalizedTitle = match.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !normalizedTitle.isEmpty else { continue }
                    let normalizedKey = normalizedTitle.lowercased()
                    guard seenTitles.insert(normalizedKey).inserted else { continue }

                    results.append(
                        SearchResult(
                            title: normalizedTitle,
                            abstract: "Matched module name in local Xcode documentation index.",
                            path: "/documentation/\(normalizedTitle)",
                            kind: .framework,
                            source: .local
                        )
                    )

                    if results.count >= 20 {
                        return results
                    }
                }
            }
        }

        return results
    }

    private func indexStoreURLs(for sdkPath: URL) -> [URL] {
        let modernIndexRoot = sdkPath
            .appendingPathComponent("DeveloperDocumentation.index")
            .appendingPathComponent("NSFileProtectionCompleteUntilFirstUserAuthentication")
            .appendingPathComponent("index.spotlightV3")

        let modernStore = modernIndexRoot.appendingPathComponent("store.db")
        if fileManager.fileExists(atPath: modernStore.path) {
            return [modernStore]
        }

        return []
    }

    private func extractPrintableStrings(from data: Data, minimumLength: Int = 4) -> [String] {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ._:/-")
        var buffer = ""
        var results: [String] = []

        for byte in data {
            if let scalar = UnicodeScalar(Int(byte)), allowed.contains(scalar) {
                buffer.unicodeScalars.append(scalar)
            } else {
                flushBuffer(&buffer, into: &results, minimumLength: minimumLength)
            }
        }

        flushBuffer(&buffer, into: &results, minimumLength: minimumLength)
        return results
    }

    private func flushBuffer(_ buffer: inout String, into results: inout [String], minimumLength: Int) {
        defer { buffer.removeAll(keepingCapacity: true) }
        let candidate = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard candidate.count >= minimumLength else { return }
        results.append(candidate)
    }

    private func isLikelyModuleQuery(_ query: String) -> Bool {
        guard !query.contains(where: \.isWhitespace) else { return false }
        guard let first = query.first, first.isUppercase else { return false }
        guard query.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil else { return false }
        let uppercaseCount = query.reduce(into: 0) { partialResult, character in
            if character.isUppercase {
                partialResult += 1
            }
        }
        return query.count >= 3 && uppercaseCount >= 2
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
