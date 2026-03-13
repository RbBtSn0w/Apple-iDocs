import Foundation

public struct URLHelpers {
    public static let appleDocBaseURL = URL(string: "https://developer.apple.com")!
    
    public static func dataURL(for path: String) -> URL? {
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "https://developer.apple.com/tutorials/data/\(cleanPath).json")
    }
    
    public static func webURL(for path: String) -> URL? {
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "https://developer.apple.com/\(cleanPath)")
    }
    
    public static func normalizePath(_ path: String) -> String {
        var normalized = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.hasPrefix("/") {
            normalized = "/" + normalized
        }
        return normalized
    }
}
