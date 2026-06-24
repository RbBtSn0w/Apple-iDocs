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

    @Test("isWithinNamespace normalizes raw paths before checking")
    func namespaceMembershipNormalizesInput() {
        #expect(DocumentationPath.isWithinNamespace("documentation/swiftui"))
        #expect(DocumentationPath.isWithinNamespace("  /documentation/swiftui  "))
        #expect(!DocumentationPath.isWithinNamespace("help/xcode"))
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
