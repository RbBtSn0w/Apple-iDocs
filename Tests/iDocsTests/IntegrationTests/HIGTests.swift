import Testing
import Foundation
@testable import iDocsKit

@Suite("HIG Tests", .enabled(if: IntegrationTestGate.isEnabled))
struct HIGTests {
    
    @Test("Fetch HIG topic")
    func fetchHIG() async throws {
        let fetcher = HIGFetcher()
        do {
            let result = try await fetcher.fetch(topic: "navigation")
            #expect(!result.isEmpty)
        } catch {
            Issue.record("HIG fetch failed. Topic: navigation Error: \(error)")
            throw error
        }
    }
    
    @Test("FetchHIGTool handles basic topic")
    func higToolBasic() async throws {
        let tool = FetchHIGTool()
        do {
            let result = try await tool.run(topic: "navigation")
            #expect(result.contains("navigation"))
        } catch {
            Issue.record("HIG tool fetch failed. Topic: navigation Error: \(error)")
            throw error
        }
    }
}
