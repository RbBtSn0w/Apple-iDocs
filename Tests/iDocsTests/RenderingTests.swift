import Testing
import Foundation
@testable import iDocs

@Suite("DocCRenderer Tests")
struct RenderingTests {
    
    @Test("Render simple metadata")
    func renderMetadata() async throws {
        let content = DocCContent(
            identifier: "doc://view",
            metadata: DocCMetadata(title: "View", role: "symbol", platforms: nil)
        )
        let renderer = DocCRenderer()
        let markdown = try renderer.render(content)
        
        #expect(markdown.contains("# View"))
    }
    
    @Test("Render declarations")
    func renderDeclarations() async throws {
        // Mock declaration section
        let renderer = DocCRenderer()
        // This will be expanded as DocCContent types are fully defined
    }
    
    @Test("Truncation strategy for large content")
    func renderTruncation() async throws {
        let renderer = DocCRenderer(maxSize: 100)
        let longText = String(repeating: "A", count: 200)
        let truncated = renderer.truncateIfNeeded(longText)
        
        #expect(truncated.count <= 150) // Including truncation message
        #expect(truncated.contains("...[Content Truncated]..."))
    }
}
