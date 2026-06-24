import Foundation

/// Curated lookup of Apple member documentation slugs whose DocC path form cannot
/// be derived from the bare member name — primarily labeled-argument signatures
/// (e.g. `present(_:animated:completion:)`) that the signature heuristics in
/// ``ResolveDocsTool`` do not generate.
///
/// Kept as data separated from the resolver logic so adding an alias does not
/// touch control flow. Fetch verification stays the correctness gate, so a stale
/// or missing entry degrades to the search fallback rather than emitting an
/// unverified path.
///
/// A static table is intentional while the set is small. If it grows to dozens
/// of curated signatures, move it to a bundled plist/JSON resource so additions
/// no longer recompile `iDocsKit` (see issue #33, finding 2).
enum ResolveDocsMemberAliases {
    /// Keyed by the compacted `framework/type/member` triple — lowercased, letters
    /// and digits only (see `ResolveDocsTool.compact`). Each value is the list of
    /// candidate path slugs to try under the type's documentation path.
    static let table: [String: [String]] = [
        "uikit/uiviewcontroller/present": ["present(_:animated:completion:)"]
    ]

    /// Candidate slugs for a compacted `framework/type/member` key, or empty when
    /// no alias is curated.
    static func slugs(forKey key: String) -> [String] {
        table[key] ?? []
    }
}
