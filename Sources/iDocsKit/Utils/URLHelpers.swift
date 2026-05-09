import Foundation

public struct URLHelpers {
    public static let appleDocBaseURL = URL(string: "https://developer.apple.com")!
    public static let sosumiBaseURL = URL(string: "https://sosumi.ai")!

    public static func searchURL(query: String) -> URL? {
        var components = URLComponents(string: "https://developer.apple.com/tutorials/data/documentation.json")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }

    public static func technologiesURL() -> URL? {
        URL(string: "https://developer.apple.com/tutorials/data/documentation/technologies.json")
    }

    public static func sosumiSearchURL(query: String) -> URL? {
        var components = URLComponents(url: sosumiBaseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }

    public static func sosumiFetchURL(for path: String) -> URL? {
        let normalizedPath = normalizePath(path)
        return URL(string: normalizedPath, relativeTo: sosumiBaseURL)?.absoluteURL
    }
    
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
