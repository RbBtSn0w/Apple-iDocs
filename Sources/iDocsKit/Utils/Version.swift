import Foundation

public let coreVersion = "1.0.0"

public struct SemVer: Sendable, Equatable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(parsing version: String) {
        let cleaned = version.split(separator: "-").first.map(String.init) ?? version
        let parts = cleaned.split(separator: ".")
        guard parts.count >= 3,
              let major = Int(parts[0]),
              let minor = Int(parts[1]),
              let patch = Int(parts[2]) else {
            return nil
        }

        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public func isMajorCompatible(with other: SemVer) -> Bool {
        major == other.major
    }
}
