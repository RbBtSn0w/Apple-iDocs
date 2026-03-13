import Foundation
@testable import iDocs

public final class MockSearchProvider: SearchProvider, @unchecked Sendable {
    public var mockResults: [URL] = []
    public var stubbedError: Error?
    
    public init(mockResults: [URL] = [], stubbedError: Error? = nil) {
        self.mockResults = mockResults
        self.stubbedError = stubbedError
    }
    
    public func search(query: String) async throws -> [URL] {
        if let error = stubbedError { throw error }
        return mockResults
    }
    
    public func reset() {
        mockResults.removeAll()
        stubbedError = nil
    }
}
