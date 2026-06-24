import Foundation

/// Canonical contract for Apple documentation paths (`/documentation/...`).
///
/// The root segment and its slash-terminated prefix are a core format contract
/// shared by URL building, source-type detection, and the local index scan.
/// Routing construction and prefix checks through these constants keeps the
/// format from drifting as the literal was previously duplicated across data
/// sources, tools, and rendering.
public enum DocumentationPath {
    /// The canonical root segment, with no trailing slash (e.g. a bare landing path).
    public static let root = "/documentation"

    /// The root followed by a trailing slash, used both as the prefix marker for
    /// namespace membership and as the base for building child paths.
    public static let prefix = "/documentation/"

    /// Builds a `/documentation/<segment>/<segment>/...` path from already-slugged
    /// segments. Callers remain responsible for slugging each segment.
    public static func make(_ segments: String...) -> String {
        make(segments)
    }

    /// Array overload of ``make(_:)-(String...)`` for dynamically built segment lists.
    public static func make(_ segments: [String]) -> String {
        prefix + segments.joined(separator: "/")
    }

    /// True when `path` is the documentation root or one of its children. The path
    /// is normalized (trimmed, leading slash) internally, so callers may pass raw
    /// paths; the check stays case-sensitive against the lowercase `prefix`.
    public static func isWithinNamespace(_ path: String) -> Bool {
        let normalized = URLHelpers.normalizePath(path)
        return normalized.hasPrefix(prefix) || normalized == root
    }
}
