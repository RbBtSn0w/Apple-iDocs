import Foundation

struct AppleDocCBlockContentParser: Sendable {
    private let inlineParser = AppleDocCInlineContentParser()

    func parseBlocks(from value: JSONValue?, path: String, context: inout AppleDocCParsingContext) -> [ContentBlock] {
        guard let value else { return [] }
        guard case .array(let blocks) = value else {
            context.appendPartial(path: path, reason: "content_blocks_not_array")
            return []
        }
        return blocks.enumerated().compactMap { index, value in
            parseBlock(value, path: "\(path)[\(index)]", context: &context)
        }
    }

    func parseBlock(_ value: JSONValue, path: String, context: inout AppleDocCParsingContext) -> ContentBlock? {
        guard case .object(let object) = value else {
            context.appendPartial(path: path, reason: "content_block_not_object")
            return nil
        }
        guard case .string(let type) = object["type"] else {
            context.appendPartial(path: "\(path).type", reason: "missing_content_block_type")
            return nil
        }

        switch type {
        case "paragraph":
            let inline = inlineParser.parseArray(from: object["inlineContent"], path: "\(path).inlineContent", context: &context) ?? []
            return inline.isEmpty ? nil : .paragraph(inline)
        case "heading":
            guard case .string(let text) = object["text"] else {
                context.appendPartial(path: "\(path).text", reason: "missing_heading_text")
                return nil
            }
            let level = parseHeadingLevel(from: object["level"], path: "\(path).level", context: &context)
            return .heading(level: level, text: text, anchor: context.string("anchor", in: object))
        case "codeListing":
            guard case .array(let lines) = object["code"] else {
                context.appendPartial(path: "\(path).code", reason: "missing_code_listing_lines")
                return nil
            }
            let code = lines.enumerated().compactMap { index, value -> String? in
                if case .string(let line) = value { return line }
                context.appendPartial(path: "\(path).code[\(index)]", reason: "code_listing_line_not_string")
                return nil
            }
            return code.isEmpty ? nil : .codeListing(syntax: context.string("syntax", in: object), code: code)
        case "aside":
            let blocks = parseBlocks(from: object["content"], path: "\(path).content", context: &context)
            guard !blocks.isEmpty else { return nil }
            return .aside(style: context.string("style", in: object) ?? "note", content: blocks)
        case "unorderedList":
            let items = parseBlockItems(from: object["items"], path: "\(path).items", context: &context)
            return items.isEmpty ? nil : .unorderedList(items)
        case "orderedList":
            let items = parseBlockItems(from: object["items"], path: "\(path).items", context: &context)
            return items.isEmpty ? nil : .orderedList(items)
        case "table":
            let header = parseBlockItems(from: object["header"], path: "\(path).header", context: &context)
            let rows = parseTableRows(from: object["rows"], path: "\(path).rows", context: &context)
            return header.isEmpty || rows.isEmpty ? nil : .table(header: header, rows: rows)
        default:
            context.appendPartial(path: path, reason: "unknown_content_block", detail: type)
            return nil
        }
    }

    private func parseHeadingLevel(from value: JSONValue?, path: String, context: inout AppleDocCParsingContext) -> Int {
        guard case .number(let rawValue) = value else {
            return 2
        }
        guard rawValue.isFinite, rawValue >= 0, rawValue <= 5 else {
            let clampedValue = rawValue.isFinite ? (rawValue < 0 ? 0 : 5) : 2
            context.appendPartial(path: path, reason: "invalid_heading_level", detail: "\(rawValue)")
            return clampedValue
        }
        return Int(rawValue)
    }

    private func parseBlockItems(from value: JSONValue?, path: String, context: inout AppleDocCParsingContext) -> [[ContentBlock]] {
        guard let value else { return [] }
        guard case .array(let items) = value else {
            context.appendPartial(path: path, reason: "block_items_not_array")
            return []
        }
        return items.enumerated().compactMap { index, value -> [ContentBlock]? in
            let blocks = parseBlocks(from: value, path: "\(path)[\(index)]", context: &context)
            return blocks.isEmpty ? nil : blocks
        }
    }

    private func parseTableRows(from value: JSONValue?, path: String, context: inout AppleDocCParsingContext) -> [[[ContentBlock]]] {
        guard let value else { return [] }
        guard case .array(let rows) = value else {
            context.appendPartial(path: path, reason: "table_rows_not_array")
            return []
        }
        return rows.enumerated().compactMap { index, value -> [[ContentBlock]]? in
            let row = parseBlockItems(from: value, path: "\(path)[\(index)]", context: &context)
            return row.isEmpty ? nil : row
        }
    }
}
