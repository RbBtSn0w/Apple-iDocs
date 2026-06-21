import Foundation

struct AppleDocCPrimarySectionParser {
    private let blockParser = AppleDocCBlockContentParser()

    func parseSections(from value: JSONValue?, path: String, context: inout AppleDocCParsingContext) -> [ContentSection]? {
        guard let value else { return nil }
        guard case .array(let sections) = value else {
            context.appendPartial(path: path, reason: "sections_not_array")
            return nil
        }
        let normalized = sections.enumerated().compactMap { index, value -> ContentSection? in
            parseSection(value, path: "\(path)[\(index)]", context: &context)
        }
        return normalized.isEmpty ? nil : normalized
    }

    private func parseSection(_ value: JSONValue, path: String, context: inout AppleDocCParsingContext) -> ContentSection? {
        guard case .object(let object) = value else {
            context.appendPartial(path: path, reason: "section_not_object")
            return nil
        }
        guard case .string(let kind) = object["kind"] else {
            context.appendPartial(path: "\(path).kind", reason: "missing_section_kind")
            return nil
        }
        switch kind {
        case "content":
            let blocks = blockParser.parseBlocks(from: object["content"], path: "\(path).content", context: &context)
            guard !blocks.isEmpty else { return nil }
            return .content(ContentBlockSection(content: blocks))
        case "declarations":
            return parseDeclarationsSection(from: object, path: path, context: &context).map(ContentSection.declarations)
        case "parameters":
            return parseParametersSection(from: object, path: path, context: &context).map(ContentSection.parameters)
        case "properties":
            return parsePropertiesSection(from: object, path: path, context: &context).map(ContentSection.properties)
        default:
            context.appendPartial(path: path, reason: "unknown_section_kind", detail: kind)
            return nil
        }
    }

    private func parseDeclarationsSection(
        from object: [String: JSONValue],
        path: String,
        context: inout AppleDocCParsingContext
    ) -> DeclarationsSection? {
        guard case .array(let values) = object["declarations"] else {
            context.appendPartial(path: "\(path).declarations", reason: "missing_declarations")
            return nil
        }
        let declarations = values.enumerated().compactMap { index, value -> Declaration? in
            let declarationPath = "\(path).declarations[\(index)]"
            guard case .object(let declarationObject) = value else {
                context.appendPartial(path: declarationPath, reason: "declaration_not_object")
                return nil
            }
            guard case .array(let tokenValues) = declarationObject["tokens"] else {
                context.appendPartial(path: "\(declarationPath).tokens", reason: "missing_declaration_tokens")
                return nil
            }
            let tokens = tokenValues.enumerated().compactMap { tokenIndex, value -> DeclarationToken? in
                let tokenPath = "\(declarationPath).tokens[\(tokenIndex)]"
                guard case .object(let tokenObject) = value else {
                    context.appendPartial(path: tokenPath, reason: "declaration_token_not_object")
                    return nil
                }
                guard let kind = context.string("kind", in: tokenObject) else {
                    context.appendPartial(path: "\(tokenPath).kind", reason: "missing_declaration_token_kind")
                    return nil
                }
                guard let text = context.string("text", in: tokenObject) else {
                    context.appendPartial(path: "\(tokenPath).text", reason: "missing_declaration_token_text")
                    return nil
                }
                return DeclarationToken(kind: kind, text: text, identifier: context.string("identifier", in: tokenObject))
            }
            guard !tokens.isEmpty else { return nil }
            return Declaration(
                tokens: tokens,
                languages: context.nonEmptyStringArray(from: declarationObject["languages"], path: "\(declarationPath).languages"),
                platforms: context.nonEmptyStringArray(from: declarationObject["platforms"], path: "\(declarationPath).platforms")
            )
        }
        return declarations.isEmpty ? nil : DeclarationsSection(declarations: declarations)
    }

    private func parseParametersSection(
        from object: [String: JSONValue],
        path: String,
        context: inout AppleDocCParsingContext
    ) -> ParametersSection? {
        guard case .array(let values) = object["parameters"] else {
            context.appendPartial(path: "\(path).parameters", reason: "missing_parameters")
            return nil
        }
        let parameters = values.enumerated().compactMap { index, value -> Parameter? in
            let parameterPath = "\(path).parameters[\(index)]"
            guard case .object(let parameterObject) = value else {
                context.appendPartial(path: parameterPath, reason: "parameter_not_object")
                return nil
            }
            guard let name = context.string("name", in: parameterObject) else {
                context.appendPartial(path: "\(parameterPath).name", reason: "missing_parameter_name")
                return nil
            }
            let blocks = blockParser.parseBlocks(from: parameterObject["content"], path: "\(parameterPath).content", context: &context)
            guard !blocks.isEmpty else {
                context.appendPartial(path: "\(parameterPath).content", reason: "missing_parameter_content")
                return nil
            }
            return Parameter(name: name, content: blocks)
        }
        return parameters.isEmpty ? nil : ParametersSection(parameters: parameters)
    }

    private func parsePropertiesSection(
        from object: [String: JSONValue],
        path: String,
        context: inout AppleDocCParsingContext
    ) -> PropertiesSection? {
        guard case .array(let values) = object["properties"] else {
            context.appendPartial(path: "\(path).properties", reason: "missing_properties")
            return nil
        }
        let properties = values.enumerated().compactMap { index, value -> Property? in
            let propertyPath = "\(path).properties[\(index)]"
            guard case .object(let propertyObject) = value else {
                context.appendPartial(path: propertyPath, reason: "property_not_object")
                return nil
            }
            guard let name = context.string("name", in: propertyObject) else {
                context.appendPartial(path: "\(propertyPath).name", reason: "missing_property_name")
                return nil
            }
            let blocks = blockParser.parseBlocks(from: propertyObject["content"], path: "\(propertyPath).content", context: &context)
            guard !blocks.isEmpty else {
                context.appendPartial(path: "\(propertyPath).content", reason: "missing_property_content")
                return nil
            }
            return Property(name: name, content: blocks)
        }
        return properties.isEmpty ? nil : PropertiesSection(properties: properties)
    }
}

struct AppleDocCTopicSectionParser {
    func parse(from value: JSONValue?, path: String, context: inout AppleDocCParsingContext) -> [TopicSection]? {
        guard let value else { return nil }
        guard case .array(let values) = value else {
            context.appendPartial(path: path, reason: "topic_sections_not_array")
            return nil
        }
        let sections = values.enumerated().compactMap { index, value -> TopicSection? in
            let sectionPath = "\(path)[\(index)]"
            guard case .object(let object) = value else {
                context.appendPartial(path: sectionPath, reason: "topic_section_not_object")
                return nil
            }
            guard let title = context.string("title", in: object) else {
                context.appendPartial(path: "\(sectionPath).title", reason: "missing_topic_title")
                return nil
            }
            let identifiers = context.stringArray(from: object["identifiers"], path: "\(sectionPath).identifiers")
            guard !identifiers.isEmpty else {
                context.appendPartial(path: "\(sectionPath).identifiers", reason: "missing_topic_identifiers")
                return nil
            }
            return TopicSection(title: title, identifiers: identifiers)
        }
        return sections.isEmpty ? nil : sections
    }
}

struct AppleDocCRelationshipSectionParser {
    func parse(from value: JSONValue?, path: String, context: inout AppleDocCParsingContext) -> [RelationshipSection]? {
        guard let value else { return nil }
        guard case .array(let values) = value else {
            context.appendPartial(path: path, reason: "relationship_sections_not_array")
            return nil
        }
        let sections = values.enumerated().compactMap { index, value -> RelationshipSection? in
            let sectionPath = "\(path)[\(index)]"
            guard case .object(let object) = value else {
                context.appendPartial(path: sectionPath, reason: "relationship_section_not_object")
                return nil
            }
            guard let title = context.string("title", in: object) else {
                context.appendPartial(path: "\(sectionPath).title", reason: "missing_relationship_title")
                return nil
            }
            let identifiers = context.stringArray(from: object["identifiers"], path: "\(sectionPath).identifiers")
            guard !identifiers.isEmpty else {
                context.appendPartial(path: "\(sectionPath).identifiers", reason: "missing_relationship_identifiers")
                return nil
            }
            return RelationshipSection(type: context.string("type", in: object) ?? "relationship", title: title, identifiers: identifiers)
        }
        return sections.isEmpty ? nil : sections
    }
}

struct AppleDocCSeeAlsoSectionParser {
    func parse(from value: JSONValue?, path: String, context: inout AppleDocCParsingContext) -> [SeeAlsoSection]? {
        guard let value else { return nil }
        guard case .array(let values) = value else {
            context.appendPartial(path: path, reason: "see_also_sections_not_array")
            return nil
        }
        let sections = values.enumerated().compactMap { index, value -> SeeAlsoSection? in
            let sectionPath = "\(path)[\(index)]"
            guard case .object(let object) = value else {
                context.appendPartial(path: sectionPath, reason: "see_also_section_not_object")
                return nil
            }
            guard let title = context.string("title", in: object) else {
                context.appendPartial(path: "\(sectionPath).title", reason: "missing_see_also_title")
                return nil
            }
            let identifiers = context.stringArray(from: object["identifiers"], path: "\(sectionPath).identifiers")
            guard !identifiers.isEmpty else {
                context.appendPartial(path: "\(sectionPath).identifiers", reason: "missing_see_also_identifiers")
                return nil
            }
            return SeeAlsoSection(title: title, identifiers: identifiers)
        }
        return sections.isEmpty ? nil : sections
    }
}

struct AppleDocCReferenceParser {
    private let inlineParser = AppleDocCInlineContentParser()

    func parse(from value: JSONValue?, path: String, context: inout AppleDocCParsingContext) -> [String: DocCReference]? {
        guard case .object(let values) = value else { return nil }
        var references: [String: DocCReference] = [:]
        for (key, value) in values {
            guard case .object(let object) = value else {
                context.appendPartial(path: "\(path)[\"\(key)\"]", reason: "reference_not_object")
                continue
            }
            guard let title = context.string("title", in: object) else {
                context.appendPartial(path: "\(path)[\"\(key)\"].title", reason: "missing_reference_title")
                continue
            }
            references[key] = DocCReference(
                title: title,
                url: context.string("url", in: object) ?? key,
                abstract: inlineParser.parseArray(
                    from: object["abstract"],
                    path: "\(path)[\"\(key)\"].abstract",
                    context: &context
                )
            )
        }
        return references.isEmpty ? nil : references
    }
}

struct AppleDocCPlatformParser {
    func parse(from value: JSONValue?, path: String, context: inout AppleDocCParsingContext) -> [PlatformAvailability]? {
        guard let value else { return nil }
        guard case .array(let values) = value else {
            context.appendPartial(path: path, reason: "platforms_not_array")
            return nil
        }
        let platforms = values.enumerated().compactMap { index, value -> PlatformAvailability? in
            let platformPath = "\(path)[\(index)]"
            guard case .object(let object) = value else {
                context.appendPartial(path: platformPath, reason: "platform_not_object")
                return nil
            }
            guard let name = context.string("name", in: object) else {
                context.appendPartial(path: "\(platformPath).name", reason: "missing_platform_name")
                return nil
            }
            return PlatformAvailability(
                name: name,
                introducedAt: context.string("introducedAt", in: object),
                deprecatedAt: context.string("deprecatedAt", in: object),
                beta: context.bool("beta", in: object)
            )
        }
        return platforms.isEmpty ? nil : platforms
    }
}
