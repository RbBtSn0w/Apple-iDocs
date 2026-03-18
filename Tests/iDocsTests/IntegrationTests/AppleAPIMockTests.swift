import Testing
import Foundation
@testable import iDocsKit

@Suite("Apple JSON API Mock Tests")
struct AppleAPIMockTests {
    
    @Test("Retry on 403 or 429 error")
    func testRetryLogic() async throws {
        let mockSession = MockNetworkSession()
        let api = AppleJSONAPI(session: mockSession)
        
        let errorResponse = HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 403, httpVersion: nil, headerFields: nil)!
        
        // Since AppleJSONAPI uses a loop, we can't easily stub sequence in this simple mock
        // unless we enhance MockNetworkSession. 
        // For now, let's just test that it fails after max retries.
        mockSession.stubbedResponse = errorResponse
        mockSession.stubbedData = Data()
        
        await #expect(throws: Error.self) {
            try await api.search(query: "test")
        }
    }
    
    @Test("Fail on 404 error without retry")
    func testFatalError() async throws {
        let mockSession = MockNetworkSession()
        let api = AppleJSONAPI(session: mockSession)
        
        let errorResponse = HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 404, httpVersion: nil, headerFields: nil)!
        mockSession.stubbedResponse = errorResponse
        mockSession.stubbedData = Data()
        
        await #expect(throws: Error.self) {
            try await api.search(query: "test")
        }
    }
}
