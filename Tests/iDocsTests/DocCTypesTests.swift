import Testing
import Foundation
@testable import iDocsKit

@Suite("DocCTypes Coverage Tests")
struct DocCTypesTests {
    
    @Test("Encode and Decode all ContentBlock types")
    func testContentBlockCodable() throws {
        let decoder = JSONDecoder()

        let paragraphJSON = """
        {\"type\":\"paragraph\",\"inlineContent\":[{\"type\":\"text\",\"text\":\"hello\"}]}
        """.data(using: .utf8)!
        _ = try decoder.decode(ContentBlock.self, from: paragraphJSON)

        let headingJSON = """
        {\"type\":\"heading\",\"level\":1,\"text\":\"H1\",\"anchor\":\"a\"}
        """.data(using: .utf8)!
        _ = try decoder.decode(ContentBlock.self, from: headingJSON)

        let codeJSON = """
        {\"type\":\"codeListing\",\"syntax\":\"swift\",\"code\":[\"let x = 1\"]}
        """.data(using: .utf8)!
        _ = try decoder.decode(ContentBlock.self, from: codeJSON)

        let asideJSON = """
        {\"type\":\"aside\",\"style\":\"note\",\"content\":[{\"type\":\"paragraph\",\"inlineContent\":[{\"type\":\"text\",\"text\":\"aside\"}]}]}
        """.data(using: .utf8)!
        _ = try decoder.decode(ContentBlock.self, from: asideJSON)

        let unorderedJSON = """
        {\"type\":\"unorderedList\",\"items\":[[{\"type\":\"paragraph\",\"inlineContent\":[{\"type\":\"text\",\"text\":\"u1\"}]}]]}
        """.data(using: .utf8)!
        _ = try decoder.decode(ContentBlock.self, from: unorderedJSON)

        let orderedJSON = """
        {\"type\":\"orderedList\",\"items\":[[{\"type\":\"paragraph\",\"inlineContent\":[{\"type\":\"text\",\"text\":\"o1\"}]}]]}
        """.data(using: .utf8)!
        _ = try decoder.decode(ContentBlock.self, from: orderedJSON)

        let tableJSON = """
        {\"type\":\"table\",\"header\":[[{\"type\":\"paragraph\",\"inlineContent\":[{\"type\":\"text\",\"text\":\"h1\"}]}]],\"rows\":[[[{\"type\":\"paragraph\",\"inlineContent\":[{\"type\":\"text\",\"text\":\"r1\"}]}]]]}
        """.data(using: .utf8)!
        _ = try decoder.decode(ContentBlock.self, from: tableJSON)
    }

    @Test("Decode InlineContent variants")
    func testInlineContentDecoding() throws {
        let decoder = JSONDecoder()

        let textJSON = """
        {\"type\":\"text\",\"text\":\"hello\"}
        """.data(using: .utf8)!
        _ = try decoder.decode(InlineContent.self, from: textJSON)

        let codeJSON = """
        {\"type\":\"codeVoice\",\"code\":\"let x\"}
        """.data(using: .utf8)!
        _ = try decoder.decode(InlineContent.self, from: codeJSON)

        let strongJSON = """
        {\"type\":\"strong\",\"inlineContent\":[{\"type\":\"text\",\"text\":\"bold\"}]}
        """.data(using: .utf8)!
        _ = try decoder.decode(InlineContent.self, from: strongJSON)

        let emphasisJSON = """
        {\"type\":\"emphasis\",\"inlineContent\":[{\"type\":\"text\",\"text\":\"em\"}]}
        """.data(using: .utf8)!
        _ = try decoder.decode(InlineContent.self, from: emphasisJSON)

        let referenceJSON = """
        {\"type\":\"reference\",\"identifier\":\"id\",\"title\":\"Ref\"}
        """.data(using: .utf8)!
        _ = try decoder.decode(InlineContent.self, from: referenceJSON)

        let imageJSON = """
        {\"type\":\"image\",\"identifier\":\"img\",\"alt\":\"alt\"}
        """.data(using: .utf8)!
        _ = try decoder.decode(InlineContent.self, from: imageJSON)

        let linkJSON = """
        {\"type\":\"link\",\"destination\":\"https://example.com\",\"title\":[{\"type\":\"text\",\"text\":\"Link\"}]}
        """.data(using: .utf8)!
        _ = try decoder.decode(InlineContent.self, from: linkJSON)
    }
    
    @Test("SourceLanguage and DocumentKind Codable")
    func testEnums() throws {
        let lang = SourceLanguage.swift
        let kind = DocumentKind.class
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let langData = try encoder.encode(lang)
        #expect(try decoder.decode(SourceLanguage.self, from: langData) == .swift)
        
        let kindData = try encoder.encode(kind)
        #expect(try decoder.decode(DocumentKind.self, from: kindData) == .class)
    }
}
