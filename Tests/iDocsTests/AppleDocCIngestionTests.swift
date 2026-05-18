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
}
