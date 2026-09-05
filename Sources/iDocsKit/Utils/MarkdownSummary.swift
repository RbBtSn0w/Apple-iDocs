import Foundation

public struct MarkdownSummary: Sendable {
    public static func title(from markdown: String, fallback: String) -> String {
        for line in markdown.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                let stripped = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                return stripped.isEmpty ? fallback : stripped
            }
        }
        return fallback
    }

    public static func summary(from markdown: String) -> String? {
        for line in markdown.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            return String(trimmed)
        }
        return nil
    }
}
