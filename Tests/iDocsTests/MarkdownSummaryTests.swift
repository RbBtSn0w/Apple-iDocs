import Testing
import Foundation
@testable import iDocsKit

@Suite("MarkdownSummary Tests")
struct MarkdownSummaryTests {
    @Test("title extracts first level 1 or lower heading")
    func titleExtractsHeading() {
        let markdown = """
        # My View
        
        This is a description of My View.
        """
        let title = MarkdownSummary.title(from: markdown, fallback: "Fallback")
        #expect(title == "My View")
    }

    @Test("title trims hashes and whitespace")
    func titleTrimsHashesAndWhitespace() {
        let markdown = "###   Advanced Navigation Split View   \nBody content"
        let title = MarkdownSummary.title(from: markdown, fallback: "Fallback")
        #expect(title == "Advanced Navigation Split View")
    }

    @Test("title preserves internal hashes within heading text")
    func titlePreservesInternalHashes() {
        let markdown = "## Issue #42: C# Programming Guide\nBody content"
        let title = MarkdownSummary.title(from: markdown, fallback: "Fallback")
        #expect(title == "Issue #42: C# Programming Guide")
    }

    @Test("title returns fallback when no heading exists")
    func titleReturnsFallbackWhenNoHeading() {
        let markdown = """
        This is just a paragraph without any heading.
        Another line.
        """
        let title = MarkdownSummary.title(from: markdown, fallback: "default/path")
        #expect(title == "default/path")
    }

    @Test("summary extracts first non-empty non-heading line")
    func summaryExtractsFirstBodyLine() {
        let markdown = """
        # Title

        A visual representation of hierarchical data.

        More details below.
        """
        let summary = MarkdownSummary.summary(from: markdown)
        #expect(summary == "A visual representation of hierarchical data.")
    }

    @Test("summary returns nil when only headings and whitespace exist")
    func summaryReturnsNilWhenOnlyHeadings() {
        let markdown = """
        # Title
        ## Subtitle
        ### Section
        """
        let summary = MarkdownSummary.summary(from: markdown)
        #expect(summary == nil)
    }

    @Test("summary returns nil for empty string")
    func summaryReturnsNilForEmpty() {
        #expect(MarkdownSummary.summary(from: "") == nil)
        #expect(MarkdownSummary.title(from: "", fallback: "Fallback") == "Fallback")
    }
}
