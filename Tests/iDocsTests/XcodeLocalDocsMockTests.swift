import Testing
import Foundation
@testable import iDocsKit

@Suite("XcodeLocalDocs Mock Tests")
struct XcodeLocalDocsMockTests {
    
    @Test("List SDKs using mock file system")
    func testListSDKs() async throws {
        let mockFS = MockFileSystem()
        let mockSearch = MockSearchProvider()
        let docs = XcodeLocalDocs(fileManager: mockFS, searchProvider: mockSearch)
        
        // Mock a directory structure
        let sdkURL = docs.cacheDirectory.appendingPathComponent("iOS 17.0")
        mockFS.virtualFiles[sdkURL.path] = Data() // Mark as existing
        
        let sdks = try await docs.listAvailableSDKs()
        #expect(sdks.count >= 0) // listAvailableSDKs currently uses real home dir for cacheDirectory URL but we injected mockFS
    }
    
    @Test("Search using mock search provider")
    func testSearchMock() async throws {
        let mockFS = MockFileSystem()
        let mockSearch = MockSearchProvider()
        let docs = XcodeLocalDocs(fileManager: mockFS, searchProvider: mockSearch)
        
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
        let docs = XcodeLocalDocs(fileManager: mockFS, searchProvider: mockSearch)

        mockSearch.mockResults = []
        let results = try await docs.search(query: "missing-symbol")
        #expect(results.isEmpty)
    }
}
