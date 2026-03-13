import Testing
import Foundation
@testable import iDocs

@Suite("XcodeLocalDocs Integration Tests")
struct XcodeLocalDocsTests {
    
    @Test("Find Xcode documentation cache directory")
    func findCacheDirectory() throws {
        let docs = XcodeLocalDocs()
        let path = docs.cacheDirectory
        #expect(path.path.contains("Library/Developer/Xcode/DocumentationCache"))
    }
    
    @Test("List installed SDK documentation")
    func listSDKDocs() async throws {
        let docs = XcodeLocalDocs()
        let sdks = try await docs.listAvailableSDKs()
        
        // This test's expectation depends on the local environment
        print("Found SDKs: \(sdks.map { $0.sdkVersion })")
    }
    
    @Test("Search local symbols")
    func searchLocalSymbols() async throws {
        let docs = XcodeLocalDocs()
        let results = try await docs.search(query: "Array")
        
        // This test's expectation depends on the local environment
        print("Local results for 'Array': \(results.count)")
    }
}
