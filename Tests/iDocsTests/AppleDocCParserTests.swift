import Foundation
import Testing
@testable import iDocsKit

@Suite("Apple DocC Parser Tests")
struct AppleDocCParserTests {
    @Test("Primary section parser records declaration token diagnostics and preserves valid declarations")
    func primarySectionParserRecordsDeclarationDiagnostics() throws {
        let section = JSONValue.object([
            "kind": .string("declarations"),
            "declarations": .array([
                .object([
                    "tokens": .array([
                        .object([
                            "kind": .string("keyword"),
                            "text": .string("struct")
                        ]),
                        .object([
                            "kind": .string("identifier")
                        ])
                    ]),
                    "languages": .array([.string("swift")])
                ])
            ])
        ])
        var context = AppleDocCParsingContext(
            root: [
                "metadata": .object([
                    "title": .string("View")
                ])
            ],
            requestedPath: "/documentation/swiftui/view"
        )

        let sections = AppleDocCPrimarySectionParser().parseSections(
            from: .array([section]),
            path: "primaryContentSections",
            context: &context
        )

        guard case .declarations(let declarations)? = sections?.first else {
            Issue.record("Expected declarations section")
            return
        }

        #expect(declarations.declarations.count == 1)
        #expect(declarations.declarations.first?.tokens.count == 1)
        #expect(context.diagnostics.contains {
            $0.path == "primaryContentSections[0].declarations[0].tokens[1].text"
                && $0.reason == "missing_declaration_token_text"
        })
    }

    @Test("Reference parser skips malformed references and keeps valid entries")
    func referenceParserSkipsMalformedReferences() throws {
        var context = AppleDocCParsingContext(
            root: [
                "metadata": .object([
                    "title": .string("View")
                ])
            ],
            requestedPath: "/documentation/swiftui/view"
        )
        let references = AppleDocCReferenceParser().parse(
            from: .object([
                "doc://valid": .object([
                    "title": .string("Valid Reference"),
                    "url": .string("/documentation/swiftui/text")
                ]),
                "doc://missing-title": .object([
                    "url": .string("/documentation/swiftui/missing")
                ]),
                "doc://not-object": .string("bad")
            ]),
            path: "references",
            context: &context
        )

        #expect(references?.count == 1)
        #expect(references?["doc://valid"]?.title == "Valid Reference")
        #expect(context.diagnostics.contains {
            $0.path == "references[\"doc://missing-title\"].title"
                && $0.reason == "missing_reference_title"
        })
        #expect(context.diagnostics.contains {
            $0.path == "references[\"doc://not-object\"]"
                && $0.reason == "reference_not_object"
        })
    }
}
