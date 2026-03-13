import Foundation
@testable import iDocs

public final class MockNetworkSession: NetworkSession, @unchecked Sendable {
    public var stubbedData: Data?
    public var stubbedResponse: URLResponse?
    public var stubbedError: Error?
    
    public init(stubbedData: Data? = nil, stubbedResponse: URLResponse? = nil, stubbedError: Error? = nil) {
        self.stubbedData = stubbedData
        self.stubbedResponse = stubbedResponse
        self.stubbedError = stubbedError
    }
    
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = stubbedError {
            throw error
        }
        
        guard let data = stubbedData, let response = stubbedResponse else {
            throw MockError.invalidResponse
        }
        
        return (data, response)
    }
    
    public func reset() {
        stubbedData = nil
        stubbedResponse = nil
        stubbedError = nil
    }
}
