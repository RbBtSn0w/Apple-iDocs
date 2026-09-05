import Foundation
import Logging

public struct XcodeLocalDocs {
    private let logger = Logger(label: "com.snow.idocs-xcode-docs")
    private static let knownModuleNames: Set<String> = [
        "accelerate",
        "accessibility",
        "appkit",
        "arkit",
        "authenticationservices",
        "avfoundation",
        "charts",
        "cloudkit",
        "combine",
        "coredata",
        "coregraphics",
        "coreimage",
        "corelocation",
        "coremedia",
        "corevideo",
        "createml",
        "foundation",
        "gamekit",
        "healthkit",
        "mapkit",
        "metal",
        "network",
        "oslog",
        "pencilkit",
        "realitykit",
        "safariservices",
        "scenekit",
        "security",
        "shazamkit",
        "spritekit",
        "storekit",
        "swift",
        "swiftdata",
        "swiftui",
        "uikit",
        "uniformtypeidentifiers",
        "usernotifications",
        "vision",
        "widgetkit"
    ]
    private let fileManager: any FileSystem
    private let searchProvider: any SearchProvider
    private let indexStoreQueryCache: IndexStoreQueryCache
    private let indexReader: IndexStoreReader
    
    public let cacheDirectory: URL
    private static let sharedIndexStoreQueryCache = IndexStoreQueryCache()

    public init(fileManager: any FileSystem = FileManager.default, 
                searchProvider: any SearchProvider = SpotlightSearchProvider(),
                cacheDirectory: URL? = nil,
                indexReader: IndexStoreReader = IndexStoreReader()) {
        self.init(
            fileManager: fileManager,
            searchProvider: searchProvider,
            cacheDirectory: cacheDirectory,
            indexStoreQueryCache: XcodeLocalDocs.sharedIndexStoreQueryCache,
            indexReader: indexReader
        )
    }

    init(fileManager: any FileSystem, 
         searchProvider: any SearchProvider,
         cacheDirectory: URL?,
         indexStoreQueryCache: IndexStoreQueryCache,
         indexReader: IndexStoreReader = IndexStoreReader()) {
        self.fileManager = fileManager
        self.searchProvider = searchProvider
        self.indexStoreQueryCache = indexStoreQueryCache
        self.indexReader = indexReader
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let userHome = URL(fileURLWithPath: NSHomeDirectory())
            self.cacheDirectory = userHome.appendingPathComponent("Library/Developer/Xcode/DocumentationCache")
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

    public func isDocumentationCacheAvailable() -> Bool {
        fileManager.fileExists(atPath: cacheDirectory.path)
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
        let dynamicModules: Set<String>? = trimmed.contains(where: \.isUppercase) ? discoveredModuleNames(sdks: sdks) : nil

        // Fast path: exact module queries can usually be satisfied from local
        // documentation roots or index stores without paying the cost of a
        // broader provider search. Symbol-like PascalCase queries must continue
        // into the broader path search so they are not misreported as modules.
        if isLikelyModuleQuery(trimmed), !isLikelySymbolName(trimmed, dynamicModules: dynamicModules) {
            let directModuleResults = searchDocumentationRoots(query: trimmed, sdks: sdks, limit: 20)
            if !directModuleResults.isEmpty {
                return directModuleResults
            }

            let directIndexResults = searchIndexStores(query: trimmed, sdks: sdks)
            if !directIndexResults.isEmpty {
                return directIndexResults
            }
        }

        if trimmed.isOpaqueMissQuery {
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
                    path: DocumentationPath.make(fileName),
                    kind: .overview,
                    source: .local
                )
            })
        }

        // Fallback path for modern Xcode caches:
        // scan DeveloperDocumentation.index store files and recover
        // /documentation/... identifiers directly from index payloads.
        if results.isEmpty {
            let indexResults = try await searchDeveloperDocumentationIndexes(query: trimmed, sdks: sdks, limit: 50)
            if !indexResults.isEmpty {
                logger.info("Recovered \(indexResults.count) matches from DeveloperDocumentation.index for: \(trimmed)")
                results = indexResults
            }
        }

        if results.isEmpty, let moduleHint = extractModuleHint(from: trimmed, dynamicModules: dynamicModules) {
            let fallback = moduleHintFallbackResults(moduleHint: moduleHint, originalQuery: trimmed, sdks: sdks)
            if !fallback.isEmpty {
                logger.info("Recovered \(fallback.count) module-level fallback matches using hint '\(moduleHint)' for query: \(trimmed)")
                return fallback
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
                
                let data = try fileManager.read(from: docPath, options: .mappedIfSafe)
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
                        path: DocumentationPath.make(module),
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
                    data = try fileManager.read(from: storeURL, options: .mappedIfSafe)
                } catch {
                    continue
                }

                guard indexReader.containsToken(query, in: data) else { continue }

                let normalizedTitle = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedTitle.isEmpty else { continue }
                let normalizedKey = normalizedTitle.lowercased()
                guard seenTitles.insert(normalizedKey).inserted else { continue }

                results.append(
                    SearchResult(
                        title: normalizedTitle,
                        abstract: "Matched module name in local Xcode documentation index.",
                        path: DocumentationPath.make(normalizedTitle),
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

    private func moduleHintFallbackResults(
        moduleHint: String,
        originalQuery: String,
        sdks: [XcodeLocalDocInfo]
    ) -> [SearchResult] {
        let rootResults = searchDocumentationRoots(query: moduleHint, sdks: sdks, limit: 20)
        if !rootResults.isEmpty {
            return rootResults.map { moduleFallbackResult($0, originalQuery: originalQuery) }
        }

        let indexResults = searchIndexStores(query: moduleHint, sdks: sdks)
        return indexResults.map { moduleFallbackResult($0, originalQuery: originalQuery) }
    }

    private func moduleFallbackResult(_ result: SearchResult, originalQuery: String) -> SearchResult {
        SearchResult(
            title: result.title,
            abstract: "Only a module-level local result was found after broader local symbol search missed for '\(originalQuery)'.",
            path: result.path,
            kind: result.kind,
            source: result.source,
            relevance: result.relevance,
            sourceKind: result.sourceKind,
            fetchSupported: result.fetchSupported,
            fetchSupportReason: result.fetchSupportReason,
            matchScope: .module,
            queryAttempt: result.queryAttempt
        )
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

    private func discoveredModuleNames(sdks: [XcodeLocalDocInfo]) -> Set<String> {
        var modules = Set<String>()
        for sdk in sdks {
            let docsDir = sdk.cachePath.appendingPathComponent("documentation")
            guard fileManager.fileExists(atPath: docsDir.path) else { continue }
            let entries = (try? fileManager.contentsOfDirectory(at: docsDir, includingPropertiesForKeys: nil, options: [])) ?? []
            for entry in entries where entry.hasDirectoryPath {
                modules.insert(entry.lastPathComponent.lowercased())
            }
        }
        return modules
    }

    private func isLikelySymbolName(_ query: String, dynamicModules: Set<String>? = nil) -> Bool {
        guard !query.contains(where: \.isWhitespace) else { return false }
        guard query.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil else { return false }
        guard let first = query.first, first.isUppercase else { return false }
        let lower = query.lowercased()
        if let dynamicModules, dynamicModules.contains(lower) {
            return false
        }
        guard !Self.knownModuleNames.contains(lower) else { return false }
        return true
    }

    private func extractModuleHint(from query: String, dynamicModules: Set<String>? = nil) -> String? {
        let tokens = query.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        for token in tokens {
            guard token.count >= 3 else { continue }
            guard let first = token.first, first.isUppercase else { continue }
            if isLikelyModuleQuery(token), !isLikelySymbolName(token, dynamicModules: dynamicModules) {
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

    private func searchDeveloperDocumentationIndexes(query: String, sdks: [XcodeLocalDocInfo], limit: Int) async throws -> [SearchResult] {
        let tokens = indexReader.tokenize(query: query)
        guard !tokens.isEmpty else { return [] }

        var ranked: [(path: String, score: Double)] = []
        var seen = Set<String>()

        for sdk in sdks where sdk.hasIndex {
            let storeURLs = indexStoreURLs(for: sdk.cachePath)
            guard !storeURLs.isEmpty else { continue }

            for storeDB in storeURLs {
                let cacheKey = indexStoreQueryCacheKey(for: storeDB, tokens: tokens)
                let cached = await indexStoreQueryCache.results(for: cacheKey)
                let storeMatches = cached ?? rankDocumentationPaths(from: storeDB, tokens: tokens, limit: limit)
                if cached == nil {
                    await indexStoreQueryCache.setResults(storeMatches, for: cacheKey)
                }

                for match in storeMatches {
                    if seen.contains(match.path) { continue }
                    seen.insert(match.path)
                    ranked.append((match.path, match.score))
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
                let title = indexReader.title(from: item.path)
                return SearchResult(
                    title: title,
                    abstract: "Matched in local Xcode documentation index.",
                    path: item.path,
                    kind: item.path.split(separator: "/").count <= 2 ? .framework : .overview,
                    source: .local,
                    relevance: item.score
                )
            }
    }

    private func rankDocumentationPaths(from url: URL, tokens: [String], limit: Int) -> [IndexStoreMatch] {
        let data: Data
        do {
            data = try fileManager.read(from: url, options: .mappedIfSafe)
        } catch {
            return []
        }

        return indexReader.rankDocumentationPaths(in: data, tokens: tokens, limit: limit)
    }

    private func indexStoreQueryCacheKey(for storeURL: URL, tokens: [String]) -> String {
        "\(storeURL.path)::\(tokens.joined(separator: "|"))"
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

actor IndexStoreQueryCache {
    private var entries: [String: [IndexStoreQueryMatch]] = [:]
    private var accessOrder: [String] = []
    let maxEntries: Int

    init(maxEntries: Int = 1000) {
        self.maxEntries = maxEntries
    }

    func results(for key: String) -> [IndexStoreQueryMatch]? {
        guard let value = entries[key] else { return nil }
        if let idx = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: idx)
            accessOrder.append(key)
        }
        return value
    }

    func setResults(_ results: [IndexStoreQueryMatch], for key: String) {
        if entries[key] != nil {
            entries[key] = results
            if let idx = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: idx)
                accessOrder.append(key)
            }
            accessOrder.append(key)
            return
        }
        if entries.count >= maxEntries, let oldest = accessOrder.first {
            entries.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }
        entries[key] = results
        accessOrder.append(key)
    }
}

public typealias IndexStoreQueryMatch = IndexStoreMatch

