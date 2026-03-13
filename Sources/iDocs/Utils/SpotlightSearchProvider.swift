import Foundation

public final class SpotlightSearchProvider: SearchProvider, @unchecked Sendable {
    public init() {}
    
    public func search(query: String) async throws -> [URL] {
        // Production implementation using NSMetadataQuery
        // For now, returning empty as actual Spotlight implementation is complex
        // and needs to be carefully integrated with the main logic.
        return []
    }
}
