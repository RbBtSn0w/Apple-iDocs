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

    var objectValue: [String: JSONValue]? {
        if case .object(let object) = self {
            return object
        }
        return nil
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
            identifier = requestedPath.map { "doc://com.apple.documentation\(URLHelpers.normalizePath($0))" }
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

        if (abstract?.isEmpty ?? true) && (primary?.isEmpty ?? true) {
            throw failure(path: "primaryContentSections", reason: "missing_renderable_content")
        }

        return AppleDocCIngestionResult(
                content: DocCContent(
                identifier: identifier,
                metadata: DocCMetadata(
                    title: title,
                    role: string(at: "metadata.role", in: object),
                    platforms: platforms(from: object["metadata"]?.objectValue?["platforms"], path: "metadata.platforms", diagnostics: &diagnostics)
                ),
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
        guard let value else { return nil }
        guard case .array(let sections) = value else {
            diagnostics.append(partial(path: path, reason: "sections_not_array"))
            return nil
        }
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
                return declarationsSection(from: object, path: sectionPath, diagnostics: &diagnostics).map(ContentSection.declarations)
            case "parameters":
                return parametersSection(from: object, path: sectionPath, diagnostics: &diagnostics).map(ContentSection.parameters)
            case "properties":
                return propertiesSection(from: object, path: sectionPath, diagnostics: &diagnostics).map(ContentSection.properties)
            default:
                diagnostics.append(partial(path: sectionPath, reason: "unknown_section_kind", detail: kind))
                return nil
            }
        }
        return normalized.isEmpty ? nil : normalized
    }

    private func declarationsSection(from object: [String: JSONValue], path: String, diagnostics: inout [AppleDocCDiagnostic]) -> DeclarationsSection? {
        guard case .array(let values) = object["declarations"] else {
            diagnostics.append(partial(path: "\(path).declarations", reason: "missing_declarations"))
            return nil
        }
        let declarations = values.enumerated().compactMap { index, value -> Declaration? in
            let declarationPath = "\(path).declarations[\(index)]"
            guard case .object(let object) = value else {
                diagnostics.append(partial(path: declarationPath, reason: "declaration_not_object"))
                return nil
            }
            guard case .array(let tokenValues) = object["tokens"] else {
                diagnostics.append(partial(path: "\(declarationPath).tokens", reason: "missing_declaration_tokens"))
                return nil
            }
            let tokens = tokenValues.enumerated().compactMap { tokenIndex, value -> DeclarationToken? in
                let tokenPath = "\(declarationPath).tokens[\(tokenIndex)]"
                guard case .object(let token) = value else {
                    diagnostics.append(partial(path: tokenPath, reason: "declaration_token_not_object"))
                    return nil
                }
                guard let kind = string("kind", in: token) else {
                    diagnostics.append(partial(path: "\(tokenPath).kind", reason: "missing_declaration_token_kind"))
                    return nil
                }
                guard let text = string("text", in: token) else {
                    diagnostics.append(partial(path: "\(tokenPath).text", reason: "missing_declaration_token_text"))
                    return nil
                }
                return DeclarationToken(kind: kind, text: text, identifier: string("identifier", in: token))
            }
            guard !tokens.isEmpty else { return nil }
            return Declaration(
                tokens: tokens,
                languages: nonEmptyStringArray(from: object["languages"], path: "\(declarationPath).languages", diagnostics: &diagnostics),
                platforms: nonEmptyStringArray(from: object["platforms"], path: "\(declarationPath).platforms", diagnostics: &diagnostics)
            )
        }
        return declarations.isEmpty ? nil : DeclarationsSection(declarations: declarations)
    }

    private func parametersSection(from object: [String: JSONValue], path: String, diagnostics: inout [AppleDocCDiagnostic]) -> ParametersSection? {
        guard case .array(let values) = object["parameters"] else {
            diagnostics.append(partial(path: "\(path).parameters", reason: "missing_parameters"))
            return nil
        }
        let parameters = values.enumerated().compactMap { index, value -> Parameter? in
            let parameterPath = "\(path).parameters[\(index)]"
            guard case .object(let object) = value else {
                diagnostics.append(partial(path: parameterPath, reason: "parameter_not_object"))
                return nil
            }
            guard let name = string("name", in: object) else {
                diagnostics.append(partial(path: "\(parameterPath).name", reason: "missing_parameter_name"))
                return nil
            }
            let blocks = contentBlocks(from: object["content"], path: "\(parameterPath).content", diagnostics: &diagnostics)
            guard !blocks.isEmpty else {
                diagnostics.append(partial(path: "\(parameterPath).content", reason: "missing_parameter_content"))
                return nil
            }
            return Parameter(name: name, content: blocks)
        }
        return parameters.isEmpty ? nil : ParametersSection(parameters: parameters)
    }

    private func propertiesSection(from object: [String: JSONValue], path: String, diagnostics: inout [AppleDocCDiagnostic]) -> PropertiesSection? {
        guard case .array(let values) = object["properties"] else {
            diagnostics.append(partial(path: "\(path).properties", reason: "missing_properties"))
            return nil
        }
        let properties = values.enumerated().compactMap { index, value -> Property? in
            let propertyPath = "\(path).properties[\(index)]"
            guard case .object(let object) = value else {
                diagnostics.append(partial(path: propertyPath, reason: "property_not_object"))
                return nil
            }
            guard let name = string("name", in: object) else {
                diagnostics.append(partial(path: "\(propertyPath).name", reason: "missing_property_name"))
                return nil
            }
            let blocks = contentBlocks(from: object["content"], path: "\(propertyPath).content", diagnostics: &diagnostics)
            guard !blocks.isEmpty else {
                diagnostics.append(partial(path: "\(propertyPath).content", reason: "missing_property_content"))
                return nil
            }
            return Property(name: name, content: blocks)
        }
        return properties.isEmpty ? nil : PropertiesSection(properties: properties)
    }

    private func contentBlocks(from value: JSONValue?, path: String, diagnostics: inout [AppleDocCDiagnostic]) -> [ContentBlock] {
        guard let value else { return [] }
        guard case .array(let blocks) = value else {
            diagnostics.append(partial(path: path, reason: "content_blocks_not_array"))
            return []
        }
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
                if value.isFinite && value >= 0 && value <= 5 {
                    level = Int(value)
                } else {
                    level = value.isFinite ? (value < 0 ? 0 : 5) : 2
                    diagnostics.append(partial(path: "\(path).level", reason: "invalid_heading_level", detail: "\(value)"))
                }
            } else {
                level = 2
            }
            return .heading(level: level, text: text, anchor: string("anchor", in: object))
        case "codeListing":
            guard case .array(let lines) = object["code"] else {
                diagnostics.append(partial(path: "\(path).code", reason: "missing_code_listing_lines"))
                return nil
            }
            let code = lines.enumerated().compactMap { index, value -> String? in
                if case .string(let line) = value { return line }
                diagnostics.append(partial(path: "\(path).code[\(index)]", reason: "code_listing_line_not_string"))
                return nil
            }
            return code.isEmpty ? nil : .codeListing(syntax: string("syntax", in: object), code: code)
        case "aside":
            let blocks = contentBlocks(from: object["content"], path: "\(path).content", diagnostics: &diagnostics)
            guard !blocks.isEmpty else { return nil }
            return .aside(style: string("style", in: object) ?? "note", content: blocks)
        case "unorderedList":
            let items = blockItems(from: object["items"], path: "\(path).items", diagnostics: &diagnostics)
            return items.isEmpty ? nil : .unorderedList(items)
        case "orderedList":
            let items = blockItems(from: object["items"], path: "\(path).items", diagnostics: &diagnostics)
            return items.isEmpty ? nil : .orderedList(items)
        case "table":
            let header = blockItems(from: object["header"], path: "\(path).header", diagnostics: &diagnostics)
            let rows = tableRows(from: object["rows"], path: "\(path).rows", diagnostics: &diagnostics)
            return header.isEmpty || rows.isEmpty ? nil : .table(header: header, rows: rows)
        default:
            diagnostics.append(partial(path: path, reason: "unknown_content_block", detail: type))
            return nil
        }
    }

    private func blockItems(from value: JSONValue?, path: String, diagnostics: inout [AppleDocCDiagnostic]) -> [[ContentBlock]] {
        guard let value else { return [] }
        guard case .array(let items) = value else {
            diagnostics.append(partial(path: path, reason: "block_items_not_array"))
            return []
        }
        return items.enumerated().compactMap { index, value -> [ContentBlock]? in
            let itemPath = "\(path)[\(index)]"
            let blocks = contentBlocks(from: value, path: itemPath, diagnostics: &diagnostics)
            return blocks.isEmpty ? nil : blocks
        }
    }

    private func tableRows(from value: JSONValue?, path: String, diagnostics: inout [AppleDocCDiagnostic]) -> [[[ContentBlock]]] {
        guard let value else { return [] }
        guard case .array(let rows) = value else {
            diagnostics.append(partial(path: path, reason: "table_rows_not_array"))
            return []
        }
        return rows.enumerated().compactMap { rowIndex, value -> [[ContentBlock]]? in
            let row = blockItems(from: value, path: "\(path)[\(rowIndex)]", diagnostics: &diagnostics)
            return row.isEmpty ? nil : row
        }
    }

    private func inlineArray(from value: JSONValue?, path: String, diagnostics: inout [AppleDocCDiagnostic]) -> [InlineContent]? {
        guard let value else { return nil }
        guard case .array(let values) = value else {
            diagnostics.append(partial(path: path, reason: "inline_array_not_array"))
            return nil
        }
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
            guard let text = string("text", in: object) else {
                diagnostics.append(partial(path: "\(path).text", reason: "missing_text"))
                return nil
            }
            return .text(text)
        case "codeVoice":
            guard let code = string("code", in: object) else {
                diagnostics.append(partial(path: "\(path).code", reason: "missing_code_voice_code"))
                return nil
            }
            return .codeVoice(code)
        case "strong":
            let inline = inlineArray(from: object["inlineContent"], path: "\(path).inlineContent", diagnostics: &diagnostics) ?? []
            return inline.isEmpty ? nil : .strong(inline)
        case "emphasis":
            let inline = inlineArray(from: object["inlineContent"], path: "\(path).inlineContent", diagnostics: &diagnostics) ?? []
            return inline.isEmpty ? nil : .emphasis(inline)
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
        guard let value else { return nil }
        guard case .array(let values) = value else {
            diagnostics.append(partial(path: path, reason: "topic_sections_not_array"))
            return nil
        }
        let sections = values.enumerated().compactMap { index, value -> TopicSection? in
            let sectionPath = "\(path)[\(index)]"
            guard case .object(let object) = value else {
                diagnostics.append(partial(path: sectionPath, reason: "topic_section_not_object"))
                return nil
            }
            guard let title = string("title", in: object) else {
                diagnostics.append(partial(path: "\(sectionPath).title", reason: "missing_topic_title"))
                return nil
            }
            let identifiers = stringArray(from: object["identifiers"], path: "\(sectionPath).identifiers", diagnostics: &diagnostics)
            guard !identifiers.isEmpty else {
                diagnostics.append(partial(path: "\(sectionPath).identifiers", reason: "missing_topic_identifiers"))
                return nil
            }
            return TopicSection(title: title, identifiers: identifiers)
        }
        return sections.isEmpty ? nil : sections
    }

    private func relationshipSections(from value: JSONValue?, path: String, diagnostics: inout [AppleDocCDiagnostic]) -> [RelationshipSection]? {
        guard let value else { return nil }
        guard case .array(let values) = value else {
            diagnostics.append(partial(path: path, reason: "relationship_sections_not_array"))
            return nil
        }
        let sections = values.enumerated().compactMap { index, value -> RelationshipSection? in
            let sectionPath = "\(path)[\(index)]"
            guard case .object(let object) = value else {
                diagnostics.append(partial(path: sectionPath, reason: "relationship_section_not_object"))
                return nil
            }
            guard let title = string("title", in: object) else {
                diagnostics.append(partial(path: "\(sectionPath).title", reason: "missing_relationship_title"))
                return nil
            }
            let type = string("type", in: object) ?? "relationship"
            let identifiers = stringArray(from: object["identifiers"], path: "\(sectionPath).identifiers", diagnostics: &diagnostics)
            guard !identifiers.isEmpty else {
                diagnostics.append(partial(path: "\(sectionPath).identifiers", reason: "missing_relationship_identifiers"))
                return nil
            }
            return RelationshipSection(type: type, title: title, identifiers: identifiers)
        }
        return sections.isEmpty ? nil : sections
    }

    private func seeAlsoSections(from value: JSONValue?, path: String, diagnostics: inout [AppleDocCDiagnostic]) -> [SeeAlsoSection]? {
        guard let value else { return nil }
        guard case .array(let values) = value else {
            diagnostics.append(partial(path: path, reason: "see_also_sections_not_array"))
            return nil
        }
        let sections = values.enumerated().compactMap { index, value -> SeeAlsoSection? in
            let sectionPath = "\(path)[\(index)]"
            guard case .object(let object) = value else {
                diagnostics.append(partial(path: sectionPath, reason: "see_also_section_not_object"))
                return nil
            }
            guard let title = string("title", in: object) else {
                diagnostics.append(partial(path: "\(sectionPath).title", reason: "missing_see_also_title"))
                return nil
            }
            let identifiers = stringArray(from: object["identifiers"], path: "\(sectionPath).identifiers", diagnostics: &diagnostics)
            guard !identifiers.isEmpty else {
                diagnostics.append(partial(path: "\(sectionPath).identifiers", reason: "missing_see_also_identifiers"))
                return nil
            }
            return SeeAlsoSection(title: title, identifiers: identifiers)
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

    private func platforms(from value: JSONValue?, path: String, diagnostics: inout [AppleDocCDiagnostic]) -> [PlatformAvailability]? {
        guard let value else { return nil }
        guard case .array(let values) = value else {
            diagnostics.append(partial(path: path, reason: "platforms_not_array"))
            return nil
        }
        let platforms = values.enumerated().compactMap { index, value -> PlatformAvailability? in
            let platformPath = "\(path)[\(index)]"
            guard case .object(let object) = value else {
                diagnostics.append(partial(path: platformPath, reason: "platform_not_object"))
                return nil
            }
            guard let name = string("name", in: object) else {
                diagnostics.append(partial(path: "\(platformPath).name", reason: "missing_platform_name"))
                return nil
            }
            return PlatformAvailability(
                name: name,
                introducedAt: string("introducedAt", in: object),
                deprecatedAt: string("deprecatedAt", in: object),
                beta: bool("beta", in: object)
            )
        }
        return platforms.isEmpty ? nil : platforms
    }

    private func stringArray(from value: JSONValue?, path: String, diagnostics: inout [AppleDocCDiagnostic]) -> [String] {
        guard let value else { return [] }
        guard case .array(let values) = value else {
            diagnostics.append(partial(path: path, reason: "string_array_not_array"))
            return []
        }
        return values.enumerated().compactMap { index, value in
            if case .string(let string) = value { return string }
            diagnostics.append(partial(path: "\(path)[\(index)]", reason: "string_array_element_not_string"))
            return nil
        }
    }

    private func nonEmptyStringArray(from value: JSONValue?, path: String, diagnostics: inout [AppleDocCDiagnostic]) -> [String]? {
        let strings = stringArray(from: value, path: path, diagnostics: &diagnostics)
        return strings.isEmpty ? nil : strings
    }

    private func string(at path: String, in root: [String: JSONValue]) -> String? {
        var current: JSONValue? = .object(root)
        for part in path.split(separator: ".") {
            guard case .object(let object) = current else { return nil }
            current = object[String(part)]
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

    private func bool(_ key: String, in object: [String: JSONValue]) -> Bool? {
        if case .bool(let value) = object[key] {
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
