import Foundation
import Testing
@testable import iDocsKit

@Suite("Apple DocC Ingestion Tests")
struct AppleDocCIngestionTests {
    @Test("JSONValue decodes nested loose Apple JSON")
    func jsonValueDecodesNestedPayload() throws {
        let data = Data("""
        {
            "string": "value",
            "number": 42,
            "bool": true,
            "array": ["a", null],
            "object": { "nested": "yes" }
        }
        """.utf8)

        let value = try JSONDecoder().decode(JSONValue.self, from: data)

        guard case .object(let object) = value else {
            Issue.record("Expected object JSONValue")
            return
        }
        #expect(object["string"] == .string("value"))
        #expect(object["number"] == .number(42))
        #expect(object["bool"] == .bool(true))
    }

    @Test("AppleDocCIngestion normalizes partial payload and records path diagnostic")
    func normalizesPartialPayloadWithDiagnostics() throws {
        let result = try AppleDocCIngestion().normalize(
            MockPayloads.docCJSONWithUnknownContentBlock(
                title: "NavigationSplitView",
                identifierURL: "doc://com.apple.SwiftUI/documentation/SwiftUI/NavigationSplitView"
            ),
            requestedPath: "/documentation/swiftui/navigationsplitview"
        )

        #expect(result.content.identifier == "doc://com.apple.SwiftUI/documentation/SwiftUI/NavigationSplitView")
        #expect(result.content.metadata.title == "NavigationSplitView")
        #expect(result.content.primaryContentSections?.count == 1)
        #expect(result.diagnostics.contains { diagnostic in
            diagnostic.reason == "unknown_content_block"
                && diagnostic.path == "primaryContentSections[0].content[1]"
        })
    }

    @Test("AppleDocCIngestion normalized content encodes stable shape")
    func normalizedContentEncodesStableShape() throws {
        let result = try AppleDocCIngestion().normalize(
            MockPayloads.docCJSONWithUnknownContentBlock(
                title: "NavigationSplitView",
                identifierURL: "doc://com.apple.SwiftUI/documentation/SwiftUI/NavigationSplitView"
            ),
            requestedPath: "/documentation/swiftui/navigationsplitview"
        )

        let encoded = try JSONEncoder().encode(result.content)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        #expect(object["identifier"] as? String == "doc://com.apple.SwiftUI/documentation/SwiftUI/NavigationSplitView")
        #expect(object["raw"] == nil)
        #expect(object["jsonValue"] == nil)

        let abstract = try #require(object["abstract"] as? [[String: Any]])
        #expect(abstract.first?["type"] as? String == "text")
        #expect(abstract.first?["text"] as? String == "Known abstract.")

        let primary = try #require(object["primaryContentSections"] as? [[String: Any]])
        #expect(primary.first?["kind"] as? String == "content")
        let blocks = try #require(primary.first?["content"] as? [[String: Any]])
        #expect(blocks.first?["type"] as? String == "paragraph")
    }

    @Test("AppleDocCIngestion fails with path-aware diagnostic when required title is missing")
    func missingRequiredCoreFailsWithPathDiagnostic() throws {
        do {
            _ = try AppleDocCIngestion().normalize(
                MockPayloads.docCJSONMissingRequiredCore(),
                requestedPath: "/documentation/swiftui/navigationsplitview"
            )
            Issue.record("Expected missing required core failure")
        } catch let error as AppleDocCIngestionError {
            #expect(error.diagnostic.severity == .failure)
            #expect(error.diagnostic.path == "metadata.title")
            #expect(error.diagnostic.reason == "missing_required_title")
        }
    }

    @Test("AppleDocCIngestion rejects references-only payload as non-renderable")
    func referencesOnlyPayloadFailsRenderableContentGate() throws {
        let data = Data("""
        {
            "identifier": "doc://com.apple.documentation/documentation/swiftui/view",
            "metadata": {
                "title": "View",
                "role": "symbol",
                "platforms": []
            },
            "references": {
                "doc://com.apple.documentation/documentation/swiftui/text": {
                    "title": "Text",
                    "url": "/documentation/swiftui/text"
                }
            }
        }
        """.utf8)

        do {
            _ = try AppleDocCIngestion().normalize(data, requestedPath: "/documentation/swiftui/view")
            Issue.record("Expected missing renderable content failure")
        } catch let error as AppleDocCIngestionError {
            #expect(error.diagnostic.path == "primaryContentSections")
            #expect(error.diagnostic.reason == "missing_renderable_content")
        }
    }

    @Test("AppleDocCIngestion records skipped loose section diagnostics")
    func recordsSkippedLooseSectionDiagnostics() throws {
        let data = Data("""
        {
            "identifier": "doc://com.apple.documentation/documentation/swiftui/view",
            "metadata": {
                "title": "View",
                "role": "symbol",
                "platforms": []
            },
            "abstract": [
                { "type": "text", "text": "Renderable abstract." },
                { "type": "codeVoice" }
            ],
            "topicSections": [
                { "title": "Topics", "identifiers": [] },
                "bad topic"
            ],
            "relationshipsSections": [
                { "title": "Related", "identifiers": [] }
            ],
            "seeAlsoSections": [
                { "identifiers": ["doc://com.apple.documentation/documentation/swiftui/text"] }
            ]
        }
        """.utf8)

        let result = try AppleDocCIngestion().normalize(data, requestedPath: "/documentation/swiftui/view")

        #expect(result.diagnostics.contains { $0.path == "abstract[1].code" && $0.reason == "missing_code_voice_code" })
        #expect(result.diagnostics.contains { $0.path == "topicSections[0].identifiers" && $0.reason == "missing_topic_identifiers" })
        #expect(result.diagnostics.contains { $0.path == "topicSections[1]" && $0.reason == "topic_section_not_object" })
        #expect(result.diagnostics.contains { $0.path == "relationshipsSections[0].identifiers" && $0.reason == "missing_relationship_identifiers" })
        #expect(result.diagnostics.contains { $0.path == "seeAlsoSections[0].title" && $0.reason == "missing_see_also_title" })
    }

    @Test("AppleDocCIngestion maps declarations and clamps invalid headings")
    func mapsDeclarationsAndClampsInvalidHeadings() throws {
        let data = Data("""
        {
            "identifier": "doc://com.apple.documentation/documentation/swiftui/view",
            "metadata": {
                "title": "View",
                "role": "symbol",
                "platforms": []
            },
            "primaryContentSections": [
                {
                    "kind": "declarations",
                    "declarations": [
                        {
                            "tokens": [
                                { "kind": "keyword", "text": "struct" },
                                { "kind": "text", "text": " " },
                                { "kind": "identifier", "text": "View" }
                            ],
                            "languages": ["swift"]
                        }
                    ]
                },
                {
                    "kind": "content",
                    "content": [
                        { "type": "heading", "level": -1, "text": "Overview" },
                        { "type": "codeListing", "syntax": "swift", "code": ["let value = 1", 42] }
                    ]
                }
            ]
        }
        """.utf8)

        let result = try AppleDocCIngestion().normalize(data, requestedPath: "/documentation/swiftui/view")

        guard case .declarations(let declarations)? = result.content.primaryContentSections?.first else {
            Issue.record("Expected declarations section")
            return
        }
        #expect(declarations.declarations.first?.tokens.map(\.text).joined() == "struct View")
        #expect(result.diagnostics.contains { $0.path == "primaryContentSections[1].content[0].level" && $0.reason == "invalid_heading_level" })
        #expect(result.diagnostics.contains { $0.path == "primaryContentSections[1].content[1].code[1]" && $0.reason == "code_listing_line_not_string" })
    }
}
