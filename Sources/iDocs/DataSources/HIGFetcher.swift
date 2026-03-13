import Foundation
import Logging

public actor HIGFetcher {
    private let logger = Logger(label: "com.snow.idocs-hig-fetcher")
    private let api = AppleJSONAPI()
    
    public init() {}
    
    public func fetch(topic: String) async throws -> String {
        logger.info("Fetching HIG topic: \(topic)")
        
        // HIG usually follows /design/human-interface-guidelines/{topic}
        // In the tutorials/data API, it might be different. 
        // For now, we'll try to fetch it via the JSON API if possible, or fallback.
        let path = "design/human-interface-guidelines/\(topic)"
        
        do {
            let doc = try await api.fetchDoc(path: path)
            return try DocCRenderer().render(doc)
        } catch {
            logger.warning("Failed to fetch HIG via JSON API: \(error.localizedDescription). Returning placeholder.")
            // Placeholder implementation for now as actual HIG URL pattern might vary
            return "HIG Content for \(topic) (Fallback/Placeholder)"
        }
    }
}
