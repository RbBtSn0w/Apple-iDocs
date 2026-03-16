import Foundation
@testable import iDocsKit

enum DocCHelpers {
    static func content(title: String) -> DocCContent {
        DocCContent(
            identifier: "doc://com.example/documentation/example",
            metadata: DocCMetadata(title: title, role: "symbol", platforms: nil),
            abstract: nil,
            primaryContentSections: nil,
            topicSections: nil,
            relationshipsSections: nil,
            seeAlsoSections: nil,
            references: nil
        )
    }
}
