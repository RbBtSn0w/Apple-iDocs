import Testing
import Foundation
@testable import iDocsKit

@Suite("DocumentationPath Tests")
struct DocumentationPathTests {
    @Test("root and prefix expose the canonical contract")
    func constants() {
        #expect(DocumentationPath.root == "/documentation")
        #expect(DocumentationPath.prefix == "/documentation/")
    }

    @Test("make joins already-slugged segments under the prefix")
    func makeJoinsSegments() {
        #expect(DocumentationPath.make("swiftui") == "/documentation/swiftui")
        #expect(DocumentationPath.make("uikit", "uiviewcontroller") == "/documentation/uikit/uiviewcontroller")
        #expect(DocumentationPath.make(["uikit", "uiviewcontroller"]) == "/documentation/uikit/uiviewcontroller")
    }

    @Test("isWithinNamespace accepts the root and its children, rejects others")
    func namespaceMembership() {
        #expect(DocumentationPath.isWithinNamespace("/documentation"))
        #expect(DocumentationPath.isWithinNamespace("/documentation/swiftui"))
        #expect(!DocumentationPath.isWithinNamespace("/documentationary"))
        #expect(!DocumentationPath.isWithinNamespace("/help/xcode"))
    }

    @Test("isWithinNamespace normalizes and lowercases raw paths before checking")
    func namespaceMembershipNormalizesInput() {
        #expect(DocumentationPath.isWithinNamespace("documentation/swiftui"))
        #expect(DocumentationPath.isWithinNamespace("  /documentation/swiftui  "))
        #expect(DocumentationPath.isWithinNamespace("/Documentation/SwiftUI"))
        #expect(DocumentationPath.isWithinNamespace("/DOCUMENTATION"))
        #expect(!DocumentationPath.isWithinNamespace("help/xcode"))
    }

    @Test("Sosumi accepts the Apple URL declared in its front matter")
    func sosumiSourcePath() {
        let markdown = "---\r\nsource: https://developer.apple.com/documentation/SwiftUI/View/onAppear%28perform%3A%29\r\n---\r\n# onAppear(perform:)"
        #expect(SosumiAPI.canonicalDocumentationPath(in: markdown) == "/documentation/swiftui/view/onappear(perform:)")
    }

    @Test("Sosumi ignores untrusted or missing documentation identity", arguments: [
        "---\nsource: https://example.com/documentation/swiftui/view\n---",
        "---\nsource: https://developer.apple.com/help/app-store-connect/\n---",
        "---\nsource: https://developer.apple.com/documentation/swiftui/view",
        "# View\n\nsource: https://developer.apple.com/documentation/swiftui/view",
        "---\nsource: https://developer.apple.com/documentation/swiftui/view\nsource: https://developer.apple.com/documentation/swiftui/list\n---"
    ])
    func untrustedSosumiSourcePath(markdown: String) {
        #expect(SosumiAPI.canonicalDocumentationPath(in: markdown) == nil)
    }

    @Test("member aliases expose curated labeled-argument slugs and miss otherwise")
    func memberAliases() {
        #expect(
            ResolveDocsMemberAliases.slugs(forKey: "uikit/uiviewcontroller/present")
                == ["present(_:animated:completion:)"]
        )
        #expect(ResolveDocsMemberAliases.slugs(forKey: "swiftui/view/body").isEmpty)
    }
}
