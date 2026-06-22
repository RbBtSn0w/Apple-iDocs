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
    private let inlineParser = AppleDocCInlineContentParser()
    private let primarySectionParser = AppleDocCPrimarySectionParser()
    private let topicSectionParser = AppleDocCTopicSectionParser()
    private let relationshipSectionParser = AppleDocCRelationshipSectionParser()
    private let seeAlsoSectionParser = AppleDocCSeeAlsoSectionParser()
    private let referenceParser = AppleDocCReferenceParser()
    private let platformParser = AppleDocCPlatformParser()

    public init() {}

    public func normalize(_ data: Data, requestedPath: String? = nil) throws -> AppleDocCIngestionResult {
        let root = try JSONDecoder().decode(JSONValue.self, from: data)
        guard case .object(let object) = root else {
            throw AppleDocCParsingContext(root: [:], requestedPath: requestedPath).failure(path: "$", reason: "root_not_object")
        }

        var context = AppleDocCParsingContext(root: object, requestedPath: requestedPath)

        let title = context.title()
        guard let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw context.failure(path: "metadata.title", reason: "missing_required_title")
        }

        let identifier = context.identifier()
        guard let identifier, !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw context.failure(path: "identifier.url", reason: "missing_required_identifier")
        }

        let abstract = inlineParser.parseArray(from: object["abstract"], path: "abstract", context: &context)
        let primary = primarySectionParser.parseSections(from: object["primaryContentSections"], path: "primaryContentSections", context: &context)
        let topics = topicSectionParser.parse(from: object["topicSections"], path: "topicSections", context: &context)
        let relationships = relationshipSectionParser.parse(from: object["relationshipsSections"], path: "relationshipsSections", context: &context)
        let seeAlso = seeAlsoSectionParser.parse(from: object["seeAlsoSections"], path: "seeAlsoSections", context: &context)
        let references = referenceParser.parse(from: object["references"], path: "references", context: &context)

        if (abstract?.isEmpty ?? true) && (primary?.isEmpty ?? true) {
            throw context.failure(path: "primaryContentSections", reason: "missing_renderable_content")
        }

        return AppleDocCIngestionResult(
            content: DocCContent(
                identifier: identifier,
                metadata: DocCMetadata(
                    title: title,
                    role: context.role(),
                    platforms: platformParser.parse(
                        from: object["metadata"]?.objectValue?["platforms"],
                        path: "metadata.platforms",
                        context: &context
                    )
                ),
                abstract: abstract,
                primaryContentSections: primary,
                topicSections: topics,
                relationshipsSections: relationships,
                seeAlsoSections: seeAlso,
                references: references
            ),
            diagnostics: context.diagnostics
        )
    }
}
