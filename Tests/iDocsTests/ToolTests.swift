import Testing
import Foundation
@testable import iDocs

@Suite("SearchDocsTool Integration Tests")
struct ToolTests {
    
    @Test("SearchDocsTool handles basic query")
    func searchToolBasic() async throws {
        // Mock data sources if needed
        let tool = SearchDocsTool()
        let result = try await tool.run(query: "View")
        
        #expect(!result.isEmpty)
        // Check for specific results based on mocks
    }
    
    @Test("SearchDocsTool handles wildcards")
    func searchToolWildcard() async throws {
        let tool = SearchDocsTool()
        let result = try await tool.run(query: "NS*Controller")
        
        #expect(!result.isEmpty)
    }
    
    @Test("BrowseTechnologiesTool lists technologies")
    func browseTechs() async throws {
        let tool = BrowseTechnologiesTool()
        let result = try await tool.run()
        #expect(!result.isEmpty)
    }
}
