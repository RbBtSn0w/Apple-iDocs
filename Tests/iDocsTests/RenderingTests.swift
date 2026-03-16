import Testing
import Foundation
@testable import iDocsKit

@Suite("DocCRenderer Exhaustive Tests")
struct RenderingTests {
    
    let renderer = DocCRenderer()
    
    @Test("Render Metadata")
    func testMetadata() throws {
        let content = DocCContent(
            identifier: "doc://test",
            metadata: DocCMetadata(title: "Test Title", role: "symbol", platforms: nil)
        )
        let result = try renderer.render(content)
        #expect(result.contains("# Test Title"))
    }
    
    @Test("Render Declarations")
    func testDeclarations() throws {
        let dec = Declaration(tokens: [
            DeclarationToken(kind: "keyword", text: "func", identifier: nil),
            DeclarationToken(kind: "text", text: " ", identifier: nil),
            DeclarationToken(kind: "identifier", text: "testMethod", identifier: nil)
        ], languages: ["swift"], platforms: nil)
        
        let section = ContentSection.declarations(DeclarationsSection(declarations: [dec]))
        let content = DocCContent(
            identifier: "doc://test",
            metadata: DocCMetadata(title: "Test", role: nil, platforms: nil),
            primaryContentSections: [section]
        )
        let result = try renderer.render(content)
        #expect(result.contains("### Declaration"))
        #expect(result.contains("```swift\nfunc testMethod\n```"))
    }
    
    @Test("Render Parameters")
    func testParameters() throws {
        let param = Parameter(name: "input", content: [.paragraph([.text("The input value.")])])
        let section = ContentSection.parameters(ParametersSection(parameters: [param]))
        let content = DocCContent(
            identifier: "doc://test",
            metadata: DocCMetadata(title: "Test", role: nil, platforms: nil),
            primaryContentSections: [section]
        )
        let result = try renderer.render(content)
        #expect(result.contains("### Parameters"))
        #expect(result.contains("- **input**: The input value."))
    }
    
    @Test("Render Properties")
    func testProperties() throws {
        let prop = Property(name: "count", content: [.paragraph([.text("The total count.")])])
        let section = ContentSection.properties(PropertiesSection(properties: [prop]))
        let content = DocCContent(
            identifier: "doc://test",
            metadata: DocCMetadata(title: "Test", role: nil, platforms: nil),
            primaryContentSections: [section]
        )
        let result = try renderer.render(content)
        #expect(result.contains("### Properties"))
        #expect(result.contains("- **count**: The total count."))
    }
    
    @Test("Render Aside (Note)")
    func testAside() throws {
        let aside = ContentBlock.aside(style: "note", content: [.paragraph([.text("This is a note.")])])
        let section = ContentSection.content(ContentBlockSection(content: [aside]))
        let content = DocCContent(
            identifier: "doc://test",
            metadata: DocCMetadata(title: "Test", role: nil, platforms: nil),
            primaryContentSections: [section]
        )
        let result = try renderer.render(content)
        #expect(result.contains("> [!NOTE]"))
        #expect(result.contains("> 📝 This is a note."))
    }
    
    @Test("Render Lists (Unordered & Ordered)")
    func testLists() throws {
        let unordered = ContentBlock.unorderedList([
            [.paragraph([.text("Item 1")])],
            [.paragraph([.text("Item 2")])]
        ])
        let ordered = ContentBlock.orderedList([
            [.paragraph([.text("First")])],
            [.paragraph([.text("Second")])]
        ])
        let section = ContentSection.content(ContentBlockSection(content: [unordered, ordered]))
        let content = DocCContent(
            identifier: "doc://test",
            metadata: DocCMetadata(title: "Test", role: nil, platforms: nil),
            primaryContentSections: [section]
        )
        let result = try renderer.render(content)
        #expect(result.contains("- Item 1"))
        #expect(result.contains("- Item 2"))
        #expect(result.contains("1. First"))
        #expect(result.contains("2. Second"))
    }
    
    @Test("Render Table")
    func testTable() throws {
        let header = [
            [ContentBlock.paragraph([.text("Col 1")])],
            [ContentBlock.paragraph([.text("Col 2")])]
        ]
        let rows = [
            [
                [ContentBlock.paragraph([.text("Val 1.1")])],
                [ContentBlock.paragraph([.text("Val 1.2")])]
            ]
        ]
        let table = ContentBlock.table(header: header, rows: rows)
        let section = ContentSection.content(ContentBlockSection(content: [table]))
        let content = DocCContent(
            identifier: "doc://test",
            metadata: DocCMetadata(title: "Test", role: nil, platforms: nil),
            primaryContentSections: [section]
        )
        let result = try renderer.render(content)
        #expect(result.contains("| Col 1 | Col 2 |"))
        #expect(result.contains("| --- | --- |"))
        #expect(result.contains("| Val 1.1 | Val 1.2 |"))
    }
    
    @Test("Render Inlines (Image & Link)")
    func testInlines() throws {
        let paragraph = ContentBlock.paragraph([
            .text("Visit "),
            .link(destination: "https://apple.com", title: [.text("Apple")]),
            .text(". "),
            .image(identifier: "logo", altText: "Logo")
        ])
        let section = ContentSection.content(ContentBlockSection(content: [paragraph]))
        let content = DocCContent(
            identifier: "doc://test",
            metadata: DocCMetadata(title: "Test", role: nil, platforms: nil),
            primaryContentSections: [section]
        )
        let result = try renderer.render(content)
        #expect(result.contains("[Apple](https://apple.com)"))
        #expect(result.contains("![Logo](logo)"))
    }
    
    @Test("Truncation Strategy")
    func testTruncation() throws {
        let customRenderer = DocCRenderer(maxSize: 20)
        let longText = String(repeating: "A", count: 100)
        let result = customRenderer.truncateIfNeeded(longText)
        #expect(result.count < longText.count)
        #expect(result.contains("...[Content Truncated due to size limit]..."))
    }
}
