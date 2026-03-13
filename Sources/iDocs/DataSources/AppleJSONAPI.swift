import Foundation
import Logging

public actor AppleJSONAPI {
    private let logger = Logger(label: "com.snow.idocs-apple-api")
    private let session = URLSession.shared
    
    public init() {}
    
    public func search(query: String) async throws -> [SearchResult] {
        guard let url = URLHelpers.dataURL(for: "search?q=\(query)") else {
            return []
        }
        
        let data = try await fetchWithRetry(url: url)
        let decoder = JSONDecoder()
        let response = try decoder.decode(AppleSearchResponse.self, from: data)
        
        return response.results.map { result in
            SearchResult(
                title: result.title,
                abstract: result.abstract,
                path: result.url,
                kind: DocumentKind(rawValue: result.type) ?? .overview,
                source: .remote
            )
        }
    }
    
    private func fetchWithRetry(url: URL, maxRetries: Int = 3) async throws -> Data {
        var lastError: Error?
        var delaySeconds: UInt64 = 1
        
        for attempt in 1...maxRetries {
            do {
                var request = URLRequest(url: url)
                request.setValue(UserAgentPool.random(), forHTTPHeaderField: "User-Agent")
                
                let (data, response) = try await session.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        return data
                    } else if httpResponse.statusCode == 403 || httpResponse.statusCode == 429 {
                        logger.warning("Attempt \(attempt) failed with status code \(httpResponse.statusCode). Retrying...")
                    } else {
                        throw iDocsError.httpError(statusCode: httpResponse.statusCode)
                    }
                }
            } catch {
                lastError = error
                logger.error("Attempt \(attempt) failed with error: \(error.localizedDescription)")
            }
            
            if attempt < maxRetries {
                try await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
                delaySeconds *= 2
            }
        }
        
        throw lastError ?? iDocsError.maxRetriesReached
    }
}

// MARK: - API Response Types

private struct AppleSearchResponse: Codable {
    let results: [AppleSearchResult]
}

private struct AppleSearchResult: Codable {
    let title: String
    let type: String
    let url: String
    let abstract: String?
}

// MARK: - Custom Errors

public enum iDocsError: Error {
    case httpError(statusCode: Int)
    case maxRetriesReached
}
