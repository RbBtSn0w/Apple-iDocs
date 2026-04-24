import Testing
import Foundation
@testable import iDocsKit

@Suite("XcodeLocalDocs Mock Tests")
struct XcodeLocalDocsMockTests {
    
    @Test("List SDKs using mock file system")
    func testListSDKs() async throws {
        let mockFS = MockFileSystem()
        let mockSearch = MockSearchProvider()
        let cacheDirectory = URL(fileURLWithPath: "/tmp/DocumentationCache", isDirectory: true)
        let docs = XcodeLocalDocs(fileManager: mockFS, searchProvider: mockSearch, cacheDirectory: cacheDirectory)
        
        // Mock a directory structure
        mockFS.virtualFiles[docs.cacheDirectory.path + "/"] = Data()
        let sdkURL = docs.cacheDirectory.appendingPathComponent("iOS 17.0")
        mockFS.virtualFiles[sdkURL.path + "/"] = Data()
        mockFS.virtualFiles[sdkURL.appendingPathComponent("DeveloperDocumentation.index").path + "/"] = Data()
        
        let sdks = try await docs.listAvailableSDKs()
        #expect(sdks.count == 1)
        #expect(sdks.first?.hasIndex == true)
    }
    
    @Test("Search using mock search provider")
    func testSearchMock() async throws {
        let mockFS = MockFileSystem()
        let mockSearch = MockSearchProvider()
        let cacheDirectory = URL(fileURLWithPath: "/tmp/DocumentationCache", isDirectory: true)
        let docs = XcodeLocalDocs(fileManager: mockFS, searchProvider: mockSearch, cacheDirectory: cacheDirectory)

        mockFS.virtualFiles[docs.cacheDirectory.path + "/"] = Data()
        let mockURL = URL(fileURLWithPath: "/tmp/DocumentationCache/documentation/swiftui/view.json")
        mockSearch.mockResults = [mockURL]
        
        let results = try await docs.search(query: "test")
        #expect(results.count == 1)
        #expect(results.first?.source == .local)
    }

    @Test("Search returns empty when no local match")
    func testSearchMiss() async throws {
        let mockFS = MockFileSystem()
        let mockSearch = MockSearchProvider()
        let cacheDirectory = URL(fileURLWithPath: "/tmp/DocumentationCache", isDirectory: true)
        let docs = XcodeLocalDocs(fileManager: mockFS, searchProvider: mockSearch, cacheDirectory: cacheDirectory)

        mockFS.virtualFiles[docs.cacheDirectory.path + "/"] = Data()
        mockSearch.mockResults = []
        let results = try await docs.search(query: "missing-symbol")
        #expect(results.isEmpty)
    }

    @Test("Module queries prefer documentation roots before provider search")
    func testModuleQueryUsesDocumentationRootFastPath() async throws {
        let mockFS = MockFileSystem()
        let mockSearch = MockSearchProvider()
        let cacheDirectory = URL(fileURLWithPath: "/tmp/DocumentationCache", isDirectory: true)
        let docs = XcodeLocalDocs(fileManager: mockFS, searchProvider: mockSearch, cacheDirectory: cacheDirectory)

        mockFS.virtualFiles[docs.cacheDirectory.path + "/"] = Data()
        let sdkURL = docs.cacheDirectory.appendingPathComponent("26.3")
        let docsRoot = sdkURL.appendingPathComponent("documentation", isDirectory: true)
        let moduleRoot = docsRoot.appendingPathComponent("SwiftData", isDirectory: true)

        mockFS.virtualFiles[sdkURL.path + "/"] = Data()
        mockFS.virtualFiles[docsRoot.path + "/"] = Data()
        mockFS.virtualFiles[moduleRoot.path + "/"] = Data()

        let results = try await docs.search(query: "SwiftData")

        #expect(results.count == 1)
        #expect(results.first?.title == "SwiftData")
        #expect(results.first?.path == "/documentation/SwiftData")
        #expect(results.first?.source == .local)
        #expect(mockSearch.searchCallCount == 0)
    }

    @Test("Non-module queries skip documentation root fast path")
    func testNonModuleQuerySkipsDocumentationRootFastPath() async throws {
        let mockFS = MockFileSystem()
        let mockSearch = MockSearchProvider()
        let cacheDirectory = URL(fileURLWithPath: "/tmp/DocumentationCache", isDirectory: true)
        let docs = XcodeLocalDocs(fileManager: mockFS, searchProvider: mockSearch, cacheDirectory: cacheDirectory)

        mockFS.virtualFiles[docs.cacheDirectory.path + "/"] = Data()
        let sdkURL = docs.cacheDirectory.appendingPathComponent("26.3")
        let docsRoot = sdkURL.appendingPathComponent("documentation", isDirectory: true)
        let moduleRoot = docsRoot.appendingPathComponent("SwiftUI", isDirectory: true)
        let providerURL = URL(fileURLWithPath: "/tmp/DocumentationCache/documentation/swiftui/view.json")

        mockFS.virtualFiles[sdkURL.path + "/"] = Data()
        mockFS.virtualFiles[docsRoot.path + "/"] = Data()
        mockFS.virtualFiles[moduleRoot.path + "/"] = Data()
        mockSearch.mockResults = [providerURL]

        let results = try await docs.search(query: "view")

        #expect(results.count == 1)
        #expect(results.first?.path == "/documentation/view")
        #expect(results.first?.source == .local)
        #expect(mockSearch.searchCallCount == 1)
    }

    @Test("Search falls back to DeveloperDocumentation.index store for module queries")
    func testSearchIndexStoreFallback() async throws {
        let mockFS = MockFileSystem()
        let mockSearch = MockSearchProvider()
        let cacheDirectory = URL(fileURLWithPath: "/tmp/DocumentationCache", isDirectory: true)
        let docs = XcodeLocalDocs(fileManager: mockFS, searchProvider: mockSearch, cacheDirectory: cacheDirectory)

        mockFS.virtualFiles[docs.cacheDirectory.path + "/"] = Data()
        let sdkURL = docs.cacheDirectory.appendingPathComponent("26.3")
        let storeURL = sdkURL
            .appendingPathComponent("DeveloperDocumentation.index")
            .appendingPathComponent("NSFileProtectionCompleteUntilFirstUserAuthentication")
            .appendingPathComponent("index.spotlightV3")
            .appendingPathComponent("store.db")

        mockFS.virtualFiles[sdkURL.path + "/"] = Data()
        mockFS.virtualFiles[sdkURL.appendingPathComponent("DeveloperDocumentation.index").path + "/"] = Data()
        mockFS.virtualFiles[storeURL.path] = Data([0x00]) + Data("SwiftUI".utf8) + Data([0x00])

        let results = try await docs.search(query: "SwiftUI")

        #expect(results.count == 1)
        #expect(results.first?.title == "SwiftUI")
        #expect(results.first?.path == "/documentation/SwiftUI")
        #expect(results.first?.source == .local)
        #expect(mockSearch.searchCallCount == 0)
    }

    @Test("Composite queries recover module hint before provider search")
    func testCompositeQueryUsesModuleHintFastPath() async throws {
        let mockFS = MockFileSystem()
        let mockSearch = MockSearchProvider()
        let cacheDirectory = URL(fileURLWithPath: "/tmp/DocumentationCache", isDirectory: true)
        let docs = XcodeLocalDocs(fileManager: mockFS, searchProvider: mockSearch, cacheDirectory: cacheDirectory)

        mockFS.virtualFiles[docs.cacheDirectory.path + "/"] = Data()
        let sdkURL = docs.cacheDirectory.appendingPathComponent("26.3")
        let storeURL = sdkURL
            .appendingPathComponent("DeveloperDocumentation.index")
            .appendingPathComponent("NSFileProtectionCompleteUntilFirstUserAuthentication")
            .appendingPathComponent("index.spotlightV3")
            .appendingPathComponent("store.db")

        mockFS.virtualFiles[sdkURL.path + "/"] = Data()
        mockFS.virtualFiles[sdkURL.appendingPathComponent("DeveloperDocumentation.index").path + "/"] = Data()
        mockFS.virtualFiles[storeURL.path] = Data([0x00]) + Data("SwiftUI".utf8) + Data([0x00])

        let results = try await docs.search(query: "SwiftUI View")

        #expect(results.count == 1)
        #expect(results.first?.title == "SwiftUI")
        #expect(results.first?.path == "/documentation/SwiftUI")
        #expect(results.first?.source == .local)
        #expect(mockSearch.searchCallCount == 0)
    }

    @Test("Search does not invent local symbol paths from index store fallback")
    func testSearchIndexStoreSkipsSymbolLikeQuery() async throws {
        let mockFS = MockFileSystem()
        let mockSearch = MockSearchProvider()
        let cacheDirectory = URL(fileURLWithPath: "/tmp/DocumentationCache", isDirectory: true)
        let docs = XcodeLocalDocs(fileManager: mockFS, searchProvider: mockSearch, cacheDirectory: cacheDirectory)

        mockFS.virtualFiles[docs.cacheDirectory.path + "/"] = Data()
        let sdkURL = docs.cacheDirectory.appendingPathComponent("26.3")
        let storeURL = sdkURL
            .appendingPathComponent("DeveloperDocumentation.index")
            .appendingPathComponent("NSFileProtectionCompleteUntilFirstUserAuthentication")
            .appendingPathComponent("index.spotlightV3")
            .appendingPathComponent("store.db")

        mockFS.virtualFiles[sdkURL.path + "/"] = Data()
        mockFS.virtualFiles[sdkURL.appendingPathComponent("DeveloperDocumentation.index").path + "/"] = Data()
        mockFS.virtualFiles[storeURL.path] = Data([0x00]) + Data("View".utf8) + Data([0x00])

        let results = try await docs.search(query: "View")

        #expect(results.isEmpty)
    }

    @Test("Opaque long miss queries skip provider fallback")
    func testOpaqueLongMissQuerySkipsProviderFallback() async throws {
        let mockFS = MockFileSystem()
        let mockSearch = MockSearchProvider()
        let cacheDirectory = URL(fileURLWithPath: "/tmp/DocumentationCache", isDirectory: true)
        let docs = XcodeLocalDocs(fileManager: mockFS, searchProvider: mockSearch, cacheDirectory: cacheDirectory)

        mockFS.virtualFiles[docs.cacheDirectory.path + "/"] = Data()
        mockSearch.mockResults = [URL(fileURLWithPath: "/tmp/DocumentationCache/documentation/placeholder.json")]

        let results = try await docs.search(query: "qwertyzzdocnotfound")

        #expect(results.isEmpty)
        #expect(mockSearch.searchCallCount == 0)
    }
}
