import Foundation

struct AppleDocCInlineContentParser: Sendable {
    func parseArray(from value: JSONValue?, path: String, context: inout AppleDocCParsingContext) -> [InlineContent]? {
        guard let value else { return nil }
        guard case .array(let values) = value else {
            context.appendPartial(path: path, reason: "inline_array_not_array")
            return nil
        }
        let inline = values.enumerated().compactMap { index, value in
            parse(value, path: "\(path)[\(index)]", context: &context)
        }
        return inline.isEmpty ? nil : inline
    }

    private func parse(_ value: JSONValue, path: String, context: inout AppleDocCParsingContext) -> InlineContent? {
        guard case .object(let object) = value else {
            context.appendPartial(path: path, reason: "inline_not_object")
            return nil
        }
        guard case .string(let type) = object["type"] else {
            context.appendPartial(path: "\(path).type", reason: "missing_inline_type")
            return nil
        }

        switch type {
        case "text":
            guard let text = context.string("text", in: object) else {
                context.appendPartial(path: "\(path).text", reason: "missing_text")
                return nil
            }
            return .text(text)
        case "codeVoice":
            guard let code = context.string("code", in: object) else {
                context.appendPartial(path: "\(path).code", reason: "missing_code_voice_code")
                return nil
            }
            return .codeVoice(code)
        case "strong":
            let inline = parseArray(from: object["inlineContent"], path: "\(path).inlineContent", context: &context) ?? []
            return inline.isEmpty ? nil : .strong(inline)
        case "emphasis":
            let inline = parseArray(from: object["inlineContent"], path: "\(path).inlineContent", context: &context) ?? []
            return inline.isEmpty ? nil : .emphasis(inline)
        case "reference":
            guard let identifier = context.string("identifier", in: object) else {
                context.appendPartial(path: "\(path).identifier", reason: "missing_reference_identifier")
                return nil
            }
            return .reference(identifier: identifier, title: context.string("title", in: object))
        case "image":
            guard let identifier = context.string("identifier", in: object) else {
                context.appendPartial(path: "\(path).identifier", reason: "missing_image_identifier")
                return nil
            }
            return .image(identifier: identifier, altText: context.string("alt", in: object))
        case "link":
            guard let destination = context.string("destination", in: object) else {
                context.appendPartial(path: "\(path).destination", reason: "missing_link_destination")
                return nil
            }
            return .link(
                destination: destination,
                title: parseArray(from: object["title"], path: "\(path).title", context: &context) ?? []
            )
        default:
            context.appendPartial(path: path, reason: "unknown_inline_content", detail: type)
            return nil
        }
    }
}
