import Foundation

public enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

public enum AppleDocCDiagnosticSeverity: String, Codable, Sendable, Equatable {
    case partial
    case failure
}

public struct AppleDocCDiagnostic: Codable, Sendable, Equatable {
    public let severity: AppleDocCDiagnosticSeverity
    public let path: String
    public let reason: String
    public let detail: String?

    public init(severity: AppleDocCDiagnosticSeverity, path: String, reason: String, detail: String? = nil) {
        self.severity = severity
        self.path = path
        self.reason = reason
        self.detail = detail
    }
}

public struct AppleDocCIngestionResult: Sendable {
    public let content: DocCContent
    public let diagnostics: [AppleDocCDiagnostic]

    public init(content: DocCContent, diagnostics: [AppleDocCDiagnostic]) {
        self.content = content
        self.diagnostics = diagnostics
    }
}

public struct AppleDocCIngestionError: Error, Sendable {
    public let diagnostic: AppleDocCDiagnostic

    public init(diagnostic: AppleDocCDiagnostic) {
        self.diagnostic = diagnostic
    }
}

public struct AppleDocCIngestion: Sendable {
    public init() {}

    public func normalize(_ data: Data, requestedPath: String? = nil) throws -> AppleDocCIngestionResult {
        let root = try JSONDecoder().decode(JSONValue.self, from: data)
        guard case .object(let object) = root else {
            throw failure(path: "$", reason: "root_not_object")
        }

        let title = string(at: "metadata.title", in: object)
        guard let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw failure(path: "metadata.title", reason: "missing_required_title")
        }

        let identifier: String?
        if let identifierValue = object["identifier"] {
            identifier = self.identifier(from: identifierValue)
        } else {
            identifier = requestedPath.map { "doc://com.apple.documentation\($0)" }
        }
        guard let identifier, !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw failure(path: "identifier.url", reason: "missing_required_identifier")
        }

        var diagnostics: [AppleDocCDiagnostic] = []
        let abstract = inlineArray(from: object["abstract"], path: "abstract", diagnostics: &diagnostics)
        let primary = contentSections(from: object["primaryContentSections"], path: "primaryContentSections", diagnostics: &diagnostics)
        let topics = topicSections(from: object["topicSections"], path: "topicSections", diagnostics: &diagnostics)
        let relationships = relationshipSections(from: object["relationshipsSections"], path: "relationshipsSections", diagnostics: &diagnostics)
        let seeAlso = seeAlsoSections(from: object["seeAlsoSections"], path: "seeAlsoSections", diagnostics: &diagnostics)
        let references = references(from: object["references"], path: "references", diagnostics: &diagnostics)

        if abstract?.isEmpty != false && primary?.isEmpty != false && references?.isEmpty != false {
            throw failure(path: "primaryContentSections", reason: "missing_renderable_content")
        }

        return AppleDocCIngestionResult(
            content: DocCContent(
                identifier: identifier,
                metadata: DocCMetadata(title: title, role: string(at: "metadata.role", in: object), platforms: nil),
                abstract: abstract,
                primaryContentSections: primary,
                topicSections: topics,
                relationshipsSections: relationships,
                seeAlsoSections: seeAlso,
                references: references
            ),
            diagnostics: diagnostics
        )
    }

    private func identifier(from value: JSONValue) -> String? {
        switch value {
        case .string(let value):
            return value
        case .object(let identifier):
            if case .string(let url) = identifier["url"] {
                return url
            }
            return nil
        default:
            return nil
        }
    }

    private func contentSections(from value: JSONValue?, path: String, diagnostics: inout [AppleDocCDiagnostic]) -> [ContentSection]? {
        guard case .array(let sections) = value else { return nil }
        let normalized = sections.enumerated().compactMap { index, value -> ContentSection? in
            let sectionPath = "\(path)[\(index)]"
            guard case .object(let object) = value else {
                diagnostics.append(partial(path: sectionPath, reason: "section_not_object"))
                return nil
            }
            guard case .string(let kind) = object["kind"] else {
                diagnostics.append(partial(path: "\(sectionPath).kind", reason: "missing_section_kind"))
                return nil
            }
            switch kind {
            case "content":
                let blocks = contentBlocks(from: object["content"], path: "\(sectionPath).content", diagnostics: &diagnostics)
                guard !blocks.isEmpty else { return nil }
                return .content(ContentBlockSection(content: blocks))
            case "declarations":
                diagnostics.append(partial(path: sectionPath, reason: "unsupported_section_kind", detail: kind))
                return nil
            default:
                diagnostics.append(partial(path: sectionPath, reason: "unknown_section_kind", detail: kind))
                return nil
            }
        }
        return normalized.isEmpty ? nil : normalized
    }

    private func contentBlocks(from value: JSONValue?, path: String, diagnostics: inout [AppleDocCDiagnostic]) -> [ContentBlock] {
        guard case .array(let blocks) = value else { return [] }
        return blocks.enumerated().compactMap { index, value in
            contentBlock(from: value, path: "\(path)[\(index)]", diagnostics: &diagnostics)
        }
    }

    private func contentBlock(from value: JSONValue, path: String, diagnostics: inout [AppleDocCDiagnostic]) -> ContentBlock? {
        guard case .object(let object) = value else {
            diagnostics.append(partial(path: path, reason: "content_block_not_object"))
            return nil
        }
        guard case .string(let type) = object["type"] else {
            diagnostics.append(partial(path: "\(path).type", reason: "missing_content_block_type"))
            return nil
        }

        switch type {
        case "paragraph":
            let inline = inlineArray(from: object["inlineContent"], path: "\(path).inlineContent", diagnostics: &diagnostics) ?? []
            return inline.isEmpty ? nil : .paragraph(inline)
        case "heading":
            guard case .string(let text) = object["text"] else {
                diagnostics.append(partial(path: "\(path).text", reason: "missing_heading_text"))
                return nil
            }
            let level: Int
            if case .number(let value) = object["level"] {
                level = Int(value)
            } else {
                level = 2
            }
            return .heading(level: level, text: text, anchor: string("anchor", in: object))
        case "codeListing":
            guard case .array(let lines) = object["code"] else {
                diagnostics.append(partial(path: "\(path).code", reason: "missing_code_listing_lines"))
                return nil
            }
            let code = lines.compactMap { value -> String? in
                if case .string(let line) = value { return line }
                return nil
            }
            return code.isEmpty ? nil : .codeListing(syntax: string("syntax", in: object), code: code)
        default:
            diagnostics.append(partial(path: path, reason: "unknown_content_block", detail: type))
            return nil
        }
    }

    private func inlineArray(from value: JSONValue?, path: String, diagnostics: inout [AppleDocCDiagnostic]) -> [InlineContent]? {
        guard case .array(let values) = value else { return nil }
        let inline = values.enumerated().compactMap { index, value in
            inlineContent(from: value, path: "\(path)[\(index)]", diagnostics: &diagnostics)
        }
        return inline.isEmpty ? nil : inline
    }

    private func inlineContent(from value: JSONValue, path: String, diagnostics: inout [AppleDocCDiagnostic]) -> InlineContent? {
        guard case .object(let object) = value else {
            diagnostics.append(partial(path: path, reason: "inline_not_object"))
            return nil
        }
        guard case .string(let type) = object["type"] else {
            diagnostics.append(partial(path: "\(path).type", reason: "missing_inline_type"))
            return nil
        }

        switch type {
        case "text":
            return string("text", in: object).map(InlineContent.text)
        case "codeVoice":
            return string("code", in: object).map(InlineContent.codeVoice)
        case "strong":
            return .strong(inlineArray(from: object["inlineContent"], path: "\(path).inlineContent", diagnostics: &diagnostics) ?? [])
        case "emphasis":
            return .emphasis(inlineArray(from: object["inlineContent"], path: "\(path).inlineContent", diagnostics: &diagnostics) ?? [])
        case "reference":
            guard let identifier = string("identifier", in: object) else {
                diagnostics.append(partial(path: "\(path).identifier", reason: "missing_reference_identifier"))
                return nil
            }
            return .reference(identifier: identifier, title: string("title", in: object))
        case "link":
            guard let destination = string("destination", in: object) else {
                diagnostics.append(partial(path: "\(path).destination", reason: "missing_link_destination"))
                return nil
            }
            return .link(destination: destination, title: inlineArray(from: object["title"], path: "\(path).title", diagnostics: &diagnostics) ?? [])
        default:
            diagnostics.append(partial(path: path, reason: "unknown_inline_content", detail: type))
            return nil
        }
    }

    private func topicSections(from value: JSONValue?, path: String, diagnostics: inout [AppleDocCDiagnostic]) -> [TopicSection]? {
        guard case .array(let values) = value else { return nil }
        let sections = values.enumerated().compactMap { index, value -> TopicSection? in
            guard case .object(let object) = value else { return nil }
            guard let title = string("title", in: object) else { return nil }
            let identifiers = stringArray(from: object["identifiers"])
            return identifiers.isEmpty ? nil : TopicSection(title: title, identifiers: identifiers)
        }
        return sections.isEmpty ? nil : sections
    }

    private func relationshipSections(from value: JSONValue?, path: String, diagnostics: inout [AppleDocCDiagnostic]) -> [RelationshipSection]? {
        guard case .array(let values) = value else { return nil }
        let sections = values.compactMap { value -> RelationshipSection? in
            guard case .object(let object) = value else { return nil }
            guard let title = string("title", in: object) else { return nil }
            let type = string("type", in: object) ?? "relationship"
            let identifiers = stringArray(from: object["identifiers"])
            return identifiers.isEmpty ? nil : RelationshipSection(type: type, title: title, identifiers: identifiers)
        }
        return sections.isEmpty ? nil : sections
    }

    private func seeAlsoSections(from value: JSONValue?, path: String, diagnostics: inout [AppleDocCDiagnostic]) -> [SeeAlsoSection]? {
        guard case .array(let values) = value else { return nil }
        let sections = values.compactMap { value -> SeeAlsoSection? in
            guard case .object(let object) = value else { return nil }
            guard let title = string("title", in: object) else { return nil }
            let identifiers = stringArray(from: object["identifiers"])
            return identifiers.isEmpty ? nil : SeeAlsoSection(title: title, identifiers: identifiers)
        }
        return sections.isEmpty ? nil : sections
    }

    private func references(from value: JSONValue?, path: String, diagnostics: inout [AppleDocCDiagnostic]) -> [String: DocCReference]? {
        guard case .object(let values) = value else { return nil }
        var references: [String: DocCReference] = [:]
        for (key, value) in values {
            guard case .object(let object) = value else {
                diagnostics.append(partial(path: "\(path)[\"\(key)\"]", reason: "reference_not_object"))
                continue
            }
            guard let title = string("title", in: object) else {
                diagnostics.append(partial(path: "\(path)[\"\(key)\"].title", reason: "missing_reference_title"))
                continue
            }
            let url = string("url", in: object) ?? key
            references[key] = DocCReference(
                title: title,
                url: url,
                abstract: inlineArray(from: object["abstract"], path: "\(path)[\"\(key)\"].abstract", diagnostics: &diagnostics)
            )
        }
        return references.isEmpty ? nil : references
    }

    private func stringArray(from value: JSONValue?) -> [String] {
        guard case .array(let values) = value else { return [] }
        return values.compactMap { value in
            if case .string(let string) = value { return string }
            return nil
        }
    }

    private func string(at path: String, in root: [String: JSONValue]) -> String? {
        let parts = path.split(separator: ".").map(String.init)
        var current: JSONValue? = .object(root)
        for part in parts {
            guard case .object(let object) = current else { return nil }
            current = object[part]
        }
        if case .string(let value) = current {
            return value
        }
        return nil
    }

    private func string(_ key: String, in object: [String: JSONValue]) -> String? {
        if case .string(let value) = object[key] {
            return value
        }
        return nil
    }

    private func partial(path: String, reason: String, detail: String? = nil) -> AppleDocCDiagnostic {
        AppleDocCDiagnostic(severity: .partial, path: path, reason: reason, detail: detail)
    }

    private func failure(path: String, reason: String, detail: String? = nil) -> AppleDocCIngestionError {
        AppleDocCIngestionError(diagnostic: AppleDocCDiagnostic(severity: .failure, path: path, reason: reason, detail: detail))
    }
}
