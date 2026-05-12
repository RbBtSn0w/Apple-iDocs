import Foundation
import Logging

public actor AppleHelpAPI {
    private let logger = Logger(label: "com.snow.idocs-apple-help-api")
    private static let titleRegex = try? NSRegularExpression(pattern: #"<h1[^>]*>(.*?)</h1>"#, options: [.caseInsensitive, .dotMatchesLineSeparators])
    private static let fallbackTitleRegex = try? NSRegularExpression(pattern: #"<title[^>]*>(.*?)</title>"#, options: [.caseInsensitive, .dotMatchesLineSeparators])
    private static let articleBlockRegex = try? NSRegularExpression(pattern: #"<(h2|h3|p)[^>]*>(.*?)</\1>"#, options: [.caseInsensitive, .dotMatchesLineSeparators])
    private let session: any NetworkSession

    public init(session: any NetworkSession = URLSession.shared) {
        self.session = session
    }

    public func fetchMarkdown(path: String) async throws -> String {
        guard let url = URLHelpers.appleHelpURL(for: path) else {
            throw iDocsError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue(UserAgentPool.random(), forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw iDocsError.invalidResponse
        }
        guard http.statusCode == 200 else {
            logger.warning("Apple Help fetch returned status \(http.statusCode) for \(path)")
            throw iDocsError.httpError(statusCode: http.statusCode)
        }
        guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
            throw iDocsError.emptyResponse
        }

        return try renderMarkdown(fromHTML: html, sourceURL: url)
    }

    private nonisolated func renderMarkdown(fromHTML html: String, sourceURL: URL) throws -> String {
        let title = firstMatch(in: html, regex: Self.titleRegex)
            ?? firstMatch(in: html, regex: Self.fallbackTitleRegex)
            ?? sourceURL.lastPathComponent

        var lines: [String] = ["# \(cleanHTML(title))", ""]
        for block in articleBlocks(in: html).prefix(14) {
            append(block: block, to: &lines)
        }
        lines.append("Source: \(sourceURL.absoluteString)")

        let markdown = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !markdown.isEmpty else {
            throw iDocsError.emptyResponse
        }
        return markdown
    }

    private nonisolated func firstMatch(in text: String, regex: NSRegularExpression?) -> String? {
        guard let regex else { return nil }
        return matches(in: text, regex: regex, captureGroup: 1).first?.value
    }

    private nonisolated func articleBlocks(in text: String) -> [(tag: String, value: String)] {
        guard let regex = Self.articleBlockRegex else { return [] }
        return matches(in: text, regex: regex, captureGroup: 2).compactMap { match in
            guard let tag = match.tag else { return nil }
            return (tag: tag, value: match.value)
        }
    }

    private nonisolated func matches(
        in text: String,
        regex: NSRegularExpression,
        captureGroup: Int
    ) -> [(tag: String?, value: String)] {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard match.numberOfRanges > captureGroup,
                  let range = Range(match.range(at: captureGroup), in: text) else {
                return nil
            }
            let tag: String?
            if match.numberOfRanges > 1, let tagRange = Range(match.range(at: 1), in: text) {
                tag = String(text[tagRange]).lowercased()
            } else {
                tag = nil
            }
            return (tag: tag, value: String(text[range]))
        }
    }

    private nonisolated func append(block: (tag: String, value: String), to lines: inout [String]) {
        let cleaned = cleanHTML(block.value)
        guard !cleaned.isEmpty else { return }

        if block.tag == "h2" || block.tag == "h3" {
            lines.append("## \(cleaned)")
        } else {
            lines.append(cleaned)
        }
        lines.append("")
    }

    private nonisolated func cleanHTML(_ value: String) -> String {
        let withoutTags = value.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        let decoded = withoutTags
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        return decoded
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
