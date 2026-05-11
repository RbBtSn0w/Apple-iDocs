import Foundation
import Logging

public actor AppleHelpAPI {
    private let logger = Logger(label: "com.snow.idocs-apple-help-api")
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
            throw iDocsError.maxRetriesReached
        }
        guard http.statusCode == 200 else {
            logger.warning("Apple Help fetch returned status \(http.statusCode) for \(path)")
            throw iDocsError.httpError(statusCode: http.statusCode)
        }
        guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
            throw iDocsError.maxRetriesReached
        }

        return try renderMarkdown(fromHTML: html, sourceURL: url)
    }

    private nonisolated func renderMarkdown(fromHTML html: String, sourceURL: URL) throws -> String {
        let title = firstMatch(in: html, pattern: #"<h1[^>]*>(.*?)</h1>"#)
            ?? firstMatch(in: html, pattern: #"<title[^>]*>(.*?)</title>"#)
            ?? sourceURL.lastPathComponent
        let headings = matches(in: html, pattern: #"<h2[^>]*>(.*?)</h2>"#)
        let paragraphs = matches(in: html, pattern: #"<p[^>]*>(.*?)</p>"#)

        var lines: [String] = ["# \(cleanHTML(title))", ""]
        for paragraph in paragraphs.prefix(8) {
            let cleaned = cleanHTML(paragraph)
            if !cleaned.isEmpty {
                lines.append(cleaned)
                lines.append("")
            }
        }
        for heading in headings.prefix(6) {
            let cleaned = cleanHTML(heading)
            if !cleaned.isEmpty {
                lines.append("## \(cleaned)")
                lines.append("")
            }
        }
        lines.append("Source: \(sourceURL.absoluteString)")

        let markdown = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !markdown.isEmpty else {
            throw iDocsError.maxRetriesReached
        }
        return markdown
    }

    private nonisolated func firstMatch(in text: String, pattern: String) -> String? {
        matches(in: text, pattern: pattern).first
    }

    private nonisolated func matches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[range])
        }
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
