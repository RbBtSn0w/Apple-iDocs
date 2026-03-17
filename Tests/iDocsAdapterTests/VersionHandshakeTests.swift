import Testing
@testable import iDocsAdapter
@testable import iDocsKit

@Suite("Version Handshake Tests")
struct VersionHandshakeTests {
    @Test("SemVer parsing succeeds for full semantic version")
    func semVerParsing() {
        let version = SemVer(parsing: "1.2.3")
        #expect(version != nil)
        #expect(version?.major == 1)
        #expect(version?.minor == 2)
        #expect(version?.patch == 3)
    }

    @Test("SemVer major compatibility check")
    func semVerMajorCompatibility() {
        let lhs = SemVer(parsing: "1.2.3")!
        let rhs = SemVer(parsing: "1.9.0")!
        let incompatible = SemVer(parsing: "2.0.0")!

        #expect(lhs.isMajorCompatible(with: rhs))
        #expect(!lhs.isMajorCompatible(with: incompatible))
    }

    @Test("Adapter version handshake fails on major mismatch")
    func versionMismatchFails() {
        #expect(throws: DocumentationError.self) {
            try DefaultDocumentationAdapter.validateVersionCompatibility(
                adapterVersion: "2.0.0",
                core: "1.0.0"
            )
        }
    }

    @Test("Adapter version handshake passes on matching major")
    func versionMatchPasses() throws {
        try DefaultDocumentationAdapter.validateVersionCompatibility(
            adapterVersion: "1.5.0",
            core: coreVersion
        )
    }
}
