import Foundation
@testable import iDocsKit

public final class MockSearchProvider: SearchProvider, @unchecked Sendable {
    public var mockResults: [URL] = []
    public var stubbedError: Error?
    public private(set) var searchCallCount = 0
    
    public init(mockResults: [URL] = [], stubbedError: Error? = nil) {
        self.mockResults = mockResults
        self.stubbedError = stubbedError
    }
    
    public func search(query: String) async throws -> [URL] {
        searchCallCount += 1
        if let error = stubbedError { throw error }
        return mockResults
    }
    
    public func reset() {
        mockResults.removeAll()
        stubbedError = nil
        searchCallCount = 0
    }
}
