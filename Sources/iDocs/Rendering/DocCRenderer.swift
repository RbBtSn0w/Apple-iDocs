import Foundation

public struct DocCRenderer {
    private let maxSize: Int
    
    public init(maxSize: Int = 100_000) {
        self.maxSize = maxSize
    }
    
    public func render(_ content: DocCContent) throws -> String {
        var markdown = ""
        
        // Title
        markdown += "# \(content.metadata.title)\n\n"
        
        // Abstract
        if let abstract = content.abstract {
            markdown += renderInline(abstract) + "\n\n"
        }
        
        // Primary Content Sections
        if let sections = content.primaryContentSections {
            for section in sections {
                markdown += renderSection(section) + "\n"
            }
        }
        
        return truncateIfNeeded(markdown)
    }
    
    // MARK: - Sections
    
    private func renderSection(_ section: ContentSection) -> String {
        switch section {
        case .declarations(let dec):
            return "### Declaration\n\n" + dec.declarations.map { renderDeclaration($0) }.joined(separator: "\n\n")
        case .parameters(let params):
            return "### Parameters\n\n" + params.parameters.map { "- **\($0.name)**: " + renderBlocks($0.content) }.joined(separator: "\n")
        case .content(let blocks):
            return renderBlocks(blocks.content)
        case .properties(let props):
            return "### Properties\n\n" + props.properties.map { "- **\($0.name)**: " + renderBlocks($0.content) }.joined(separator: "\n")
        }
    }
    
    private func renderDeclaration(_ dec: Declaration) -> String {
        var code = "```swift\n"
        code += dec.tokens.map { $0.text }.joined()
        code += "\n```"
        return code
    }
    
    // MARK: - Blocks
    
    private func renderBlocks(_ blocks: [ContentBlock]) -> String {
        return blocks.map { renderBlock($0) }.joined(separator: "\n\n")
    }
    
    private func renderBlock(_ block: ContentBlock) -> String {
        switch block {
        case .paragraph(let inline):
            return renderInline(inline)
        case .heading(let level, let text, _):
            return String(repeating: "#", count: level + 1) + " " + text
        case .codeListing(let syntax, let code):
            return "```\(syntax ?? "")\n" + code.joined(separator: "\n") + "\n```"
        case .aside(let style, let content):
            let icon: String
            switch style {
            case "note": icon = "📝"
            case "warning": icon = "⚠️"
            case "important": icon = "💡"
            default: icon = "ℹ️"
            }
            return "> [!\(style.uppercased())]\n> \(icon) " + renderBlocks(content).replacingOccurrences(of: "\n", with: "\n> ")
        case .unorderedList(let items):
            return items.map { "- " + renderBlocks($0).replacingOccurrences(of: "\n", with: "\n  ") }.joined(separator: "\n")
        case .orderedList(let items):
            return items.enumerated().map { "\($0 + 1). " + renderBlocks($1).replacingOccurrences(of: "\n", with: "\n   ") }.joined(separator: "\n")
        case .table(let header, let rows):
            var table = ""
            // Header
            table += "| " + header.map { renderBlocks($0) }.joined(separator: " | ") + " |\n"
            table += "| " + header.map { _ in "---" }.joined(separator: " | ") + " |\n"
            // Rows
            for row in rows {
                table += "| " + row.map { renderBlocks($0) }.joined(separator: " | ") + " |\n"
            }
            return table
        }
    }
    
    // MARK: - Inline
    
    private func renderInline(_ content: [InlineContent]) -> String {
        return content.map { renderInlineItem($0) }.joined()
    }
    
    private func renderInlineItem(_ item: InlineContent) -> String {
        switch item {
        case .text(let text):
            return text
        case .codeVoice(let code):
            return "`\(code)`"
        case .strong(let content):
            return "**\(renderInline(content))**"
        case .emphasis(let content):
            return " *\(renderInline(content))*"
        case .reference(_, let title):
            return title ?? "Reference"
        case .image(let id, let alt):
            return "![\(alt ?? id)](\(id))"
        case .link(let dest, let title):
            return "[\(renderInline(title))](\(dest))"
        }
    }
    
    // MARK: - Truncation
    
    public func truncateIfNeeded(_ markdown: String) -> String {
        if markdown.count > maxSize {
            let truncated = String(markdown.prefix(maxSize))
            return truncated + "\n\n...[Content Truncated due to size limit]..."
        }
        return markdown
    }
}
