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

        // Fast path: module-style queries can usually be satisfied from local
        // documentation roots or index stores without paying the cost of a
        // broader provider search.
        if isLikelyModuleQuery(trimmed) {
            let directModuleResults = searchDocumentationRoots(query: trimmed, sdks: sdks, limit: 20)
            if !directModuleResults.isEmpty {
                return directModuleResults
            }

            let directIndexResults = searchIndexStores(query: trimmed, sdks: sdks)
            if !directIndexResults.isEmpty {
                return directIndexResults
            }
        }

        // Composite queries such as "SwiftUI View" still benefit from resolving
        // the framework/module token first before searching more broadly.
        if let moduleHint = extractModuleHint(from: trimmed) {
            let hinted = searchDocumentationRoots(query: moduleHint, sdks: sdks, limit: 20)
            if !hinted.isEmpty {
                logger.info("Recovered \(hinted.count) module-level matches using hint '\(moduleHint)' for query: \(trimmed)")
                return hinted
            }

            let hintedIndexResults = searchIndexStores(query: moduleHint, sdks: sdks)
            if !hintedIndexResults.isEmpty {
                logger.info("Recovered \(hintedIndexResults.count) module-level matches using hint '\(moduleHint)' for query: \(trimmed)")
                return hintedIndexResults
            }
        }

        if shouldShortCircuitOpaqueMissQuery(trimmed) {
            logger.info("Skipping expensive local miss path for opaque query: \(trimmed)")
            return []
        }

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

        // Fallback path for modern Xcode caches:
        // scan DeveloperDocumentation.index store files and recover
        // /documentation/... identifiers directly from index payloads.
        if results.isEmpty {
            let indexResults = try searchDeveloperDocumentationIndexes(query: trimmed, sdks: sdks, limit: 50)
            if !indexResults.isEmpty {
                logger.info("Recovered \(indexResults.count) matches from DeveloperDocumentation.index for: \(trimmed)")
                results = indexResults
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

    private func searchDocumentationRoots(query: String, sdks: [XcodeLocalDocInfo], limit: Int) -> [SearchResult] {
        let needle = query.lowercased()
        guard !needle.isEmpty else { return [] }

        var results: [SearchResult] = []
        var seenModules = Set<String>()

        for sdk in sdks {
            let docsDir = sdk.cachePath.appendingPathComponent("documentation")
            guard fileManager.fileExists(atPath: docsDir.path) else { continue }
            let entries = (try? fileManager.contentsOfDirectory(at: docsDir, includingPropertiesForKeys: nil, options: [])) ?? []
            for entry in entries where entry.hasDirectoryPath {
                let module = entry.lastPathComponent
                guard module.lowercased().contains(needle) else { continue }

                let normalizedKey = module.lowercased()
                guard seenModules.insert(normalizedKey).inserted else { continue }

                results.append(
                    SearchResult(
                        title: module,
                        abstract: "Matched module name in local Xcode documentation.",
                        path: "/documentation/\(module)",
                        kind: .framework,
                        source: .local
                    )
                )

                if results.count >= limit {
                    return results
                }
            }
        }

        return results
    }

    private func searchIndexStores(query: String, sdks: [XcodeLocalDocInfo]) -> [SearchResult] {
        guard isLikelyModuleQuery(query) else { return [] }

        var seenTitles = Set<String>()
        var results: [SearchResult] = []

        for sdk in sdks where sdk.hasIndex {
            for storeURL in indexStoreURLs(for: sdk.cachePath) {
                let data: Data
                do {
                    if fileManager is FileManager {
                        data = try Data(contentsOf: storeURL, options: .mappedIfSafe)
                    } else {
                        data = try fileManager.read(from: storeURL)
                    }
                } catch {
                    continue
                }

                guard containsToken(query, in: data) else { continue }

                let normalizedTitle = query.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func containsToken(_ token: String, in data: Data) -> Bool {
        guard let needle = token.data(using: .utf8), !needle.isEmpty else { return false }
        let moduleCharacterSet = CharacterSet.alphanumerics

        var searchRange = 0..<data.count
        while let matchRange = data.range(of: needle, options: [], in: searchRange) {
            let lowerBound = matchRange.lowerBound
            let upperBound = matchRange.upperBound
            let hasLeadingBoundary = lowerBound == data.startIndex || !isModuleByte(data[lowerBound - 1], moduleCharacterSet: moduleCharacterSet)
            let hasTrailingBoundary = upperBound == data.endIndex || !isModuleByte(data[upperBound], moduleCharacterSet: moduleCharacterSet)
            if hasLeadingBoundary && hasTrailingBoundary {
                return true
            }

            searchRange = upperBound..<data.count
        }

        return false
    }

    private func isModuleByte(_ byte: UInt8, moduleCharacterSet: CharacterSet) -> Bool {
        guard let scalar = UnicodeScalar(Int(byte)) else { return false }
        return moduleCharacterSet.contains(scalar)
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

    private func shouldShortCircuitOpaqueMissQuery(_ query: String) -> Bool {
        guard !query.contains(where: \.isWhitespace) else { return false }
        guard query.count >= 16 else { return false }
        guard let first = query.first, first.isLowercase else { return false }
        guard query.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil else { return false }
        return query.lowercased() == query
    }

    private func extractModuleHint(from query: String) -> String? {
        let tokens = query.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        for token in tokens {
            guard token.count >= 3 else { continue }
            guard let first = token.first, first.isUppercase else { continue }
            if isLikelyModuleQuery(token) {
                return token
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

    private func searchDeveloperDocumentationIndexes(query: String, sdks: [XcodeLocalDocInfo], limit: Int) throws -> [SearchResult] {
        let tokens = tokenize(query: query)
        guard !tokens.isEmpty else { return [] }

        var ranked: [(path: String, score: Double)] = []
        var seen = Set<String>()

        for sdk in sdks where sdk.hasIndex {
            let storeURLs = indexStoreURLs(for: sdk.cachePath)
            guard !storeURLs.isEmpty else { continue }

            for storeDB in storeURLs {
                for path in extractDocumentationPaths(from: storeDB) {
                    if seen.contains(path) { continue }
                    let score = scoreForPath(path, tokens: tokens)
                    guard score > 0 else { continue }
                    seen.insert(path)
                    ranked.append((path, score))
                }
            }
        }

        return ranked
            .sorted { lhs, rhs in
                if lhs.score == rhs.score { return lhs.path < rhs.path }
                return lhs.score > rhs.score
            }
            .prefix(limit)
            .map { item in
                let title = titleFromPath(item.path)
                return SearchResult(
                    title: title,
                    abstract: "Matched in local Xcode documentation index.",
                    path: item.path,
                    kind: item.path.split(separator: "/").count <= 3 ? .framework : .overview,
                    source: .local,
                    relevance: item.score
                )
            }
    }

    private func extractDocumentationPaths(from url: URL) -> [String] {
        let data: Data
        do {
            if fileManager is FileManager {
                data = try Data(contentsOf: url, options: .mappedIfSafe)
            } else {
                data = try fileManager.read(from: url)
            }
        } catch {
            return []
        }

        let prefix = Array("/documentation/".utf8)
        var matches = Set<String>()
        let maxPathLength = 240

        data.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            guard bytes.count > prefix.count else { return }

            var i = 0
            while i + prefix.count < bytes.count {
                var found = true
                for j in 0..<prefix.count where bytes[i + j] != prefix[j] {
                    found = false
                    break
                }
                if !found {
                    i += 1
                    continue
                }

                var end = i + prefix.count
                while end < bytes.count && end - i < maxPathLength && isPathByte(bytes[end]) {
                    end += 1
                }

                let length = end - i
                if length > prefix.count + 1,
                   let base = bytes.baseAddress {
                    let candidate = Data(bytes: base.advanced(by: i), count: length)
                    if let path = String(data: candidate, encoding: .utf8),
                       path.hasPrefix("/documentation/") {
                        matches.insert(path)
                    }
                }
                i = end
            }
        }

        return Array(matches)
    }

    private func isPathByte(_ byte: UInt8) -> Bool {
        switch byte {
        case 48...57, 65...90, 97...122, 45, 46, 47, 95:
            return true
        default:
            return false
        }
    }

    private func tokenize(query: String) -> [String] {
        query
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func scoreForPath(_ path: String, tokens: [String]) -> Double {
        let lower = path.lowercased()
        var score = 0.0
        var matchedCount = 0
        for token in tokens {
            if lower.hasSuffix("/\(token)") { score += 50 }
            if lower.contains("/\(token)") { score += 20 }
            if lower.contains(token) {
                score += 10
                matchedCount += 1
            }
        }
        if matchedCount == 0 { return 0 }
        score += Double(matchedCount) * 15
        score -= Double(path.count) * 0.01
        return score
    }

    private func titleFromPath(_ path: String) -> String {
        let components = path.split(separator: "/")
        guard let raw = components.last else { return path }
        let normalized = raw.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
        return normalized
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
