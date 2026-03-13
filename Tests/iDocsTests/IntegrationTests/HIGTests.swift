import Testing
import Foundation
@testable import iDocs

@Suite("HIG Tests")
struct HIGTests {
    
    @Test("Fetch HIG topic")
    func fetchHIG() async throws {
        let fetcher = HIGFetcher()
        let result = try await fetcher.fetch(topic: "navigation")
        
        #expect(!result.isEmpty)
    }
    
    @Test("FetchHIGTool handles basic topic")
    func higToolBasic() async throws {
        let tool = FetchHIGTool()
        let result = try await tool.run(topic: "navigation")
        
        #expect(result.contains("navigation"))
    }
}
