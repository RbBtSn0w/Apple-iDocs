import Foundation

struct AppleDocCParsingContext {
    let root: [String: JSONValue]
    let requestedPath: String?
    var diagnostics: [AppleDocCDiagnostic] = []

    func title() -> String? {
        string(at: "metadata.title", in: root)
    }

    func identifier() -> String? {
        if let identifierValue = root["identifier"] {
            return identifier(from: identifierValue)
        }
        guard let requestedPath else { return nil }
        return "doc://com.apple.documentation\(URLHelpers.normalizePath(requestedPath))"
    }

    func role() -> String? {
        string(at: "metadata.role", in: root)
    }

    mutating func appendPartial(path: String, reason: String, detail: String? = nil) {
        diagnostics.append(AppleDocCDiagnostic(severity: .partial, path: path, reason: reason, detail: detail))
    }

    func failure(path: String, reason: String, detail: String? = nil) -> AppleDocCIngestionError {
        AppleDocCIngestionError(
            diagnostic: AppleDocCDiagnostic(severity: .failure, path: path, reason: reason, detail: detail)
        )
    }

    func identifier(from value: JSONValue) -> String? {
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

    func string(at path: String, in root: [String: JSONValue]) -> String? {
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

    func string(_ key: String, in object: [String: JSONValue]) -> String? {
        if case .string(let value) = object[key] {
            return value
        }
        return nil
    }

    func bool(_ key: String, in object: [String: JSONValue]) -> Bool? {
        if case .bool(let value) = object[key] {
            return value
        }
        return nil
    }

    mutating func stringArray(from value: JSONValue?, path: String) -> [String] {
        guard let value else { return [] }
        guard case .array(let values) = value else {
            appendPartial(path: path, reason: "string_array_not_array")
            return []
        }
        return values.enumerated().compactMap { index, value in
            if case .string(let string) = value { return string }
            appendPartial(path: "\(path)[\(index)]", reason: "string_array_element_not_string")
            return nil
        }
    }

    mutating func nonEmptyStringArray(from value: JSONValue?, path: String) -> [String]? {
        let strings = stringArray(from: value, path: path)
        return strings.isEmpty ? nil : strings
    }
}
