import Foundation
import Logging

public actor ExternalDocCFetcher {
    private let logger = Logger(label: "com.snow.idocs-external-doc-fetcher")
    private let session: any NetworkSession
    
    public init(session: any NetworkSession = URLSession.shared) {
        self.session = session
    }
    
    public func fetch(url: URL) async throws -> DocCContent {
        logger.info("Fetching external DocC content from: \(url.absoluteString)")
        
        // Convert web URL to data URL if necessary
        // Example: swiftpackageindex.com/.../documentation/algorithms/chain
        // Data URL: swiftpackageindex.com/.../data/documentation/algorithms/chain.json
        let dataURL = convertToDataURL(url)
        
        var request = URLRequest(url: dataURL)
        request.setValue(UserAgentPool.random(), forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw iDocsError.httpError(statusCode: status)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(DocCContent.self, from: data)
    }
    
    private func convertToDataURL(_ url: URL) -> URL {
        var path = url.path
        if path.contains("/documentation/") {
            path = path.replacingOccurrences(of: "/documentation/", with: "/data/documentation/")
        }
        if !path.hasSuffix(".json") {
            path += ".json"
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.path = path
        return components?.url ?? url
    }
}
