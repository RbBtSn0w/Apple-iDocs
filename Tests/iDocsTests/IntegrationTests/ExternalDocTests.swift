import Testing
import Foundation
@testable import iDocs

@Suite("External DocC Tests")
struct ExternalDocTests {
    
    @Test("Fetch external DocC JSON")
    func fetchExternalDoc() async throws {
        let fetcher = ExternalDocCFetcher()
        let url = URL(string: "https://swiftpackageindex.com/apple/swift-algorithms/documentation/algorithms/chain")!
        let doc = try await fetcher.fetch(url: url)
        
        #expect(doc.metadata.title != "")
    }
}
