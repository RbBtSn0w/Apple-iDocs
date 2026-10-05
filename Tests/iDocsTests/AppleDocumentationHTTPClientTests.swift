import Testing
import Foundation
@testable import iDocsKit

@Suite("Apple Documentation HTTP Client Tests")
struct AppleDocumentationHTTPClientTests {

    @Test("fetchWithRetry succeeds on 200 response")
    func fetchSucceedsOn200() async throws {
        let session = MockNetworkSession()
        let url = URL(string: "https://developer.apple.com/test")!
        let expectedData = "OK".data(using: .utf8)!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        session.setResponse(for: url, data: expectedData, response: response)

        let client = AppleDocumentationHTTPClient(session: session, retryDelayNanoseconds: 0)
        let data = try await client.fetchWithRetry(url: url)
        #expect(data == expectedData)
        #expect(session.requestCount == 1)
    }

    @Test("fetchWithRetry retries on 429 and eventually throws")
    func fetchRetriesOn429() async throws {
        let session = MockNetworkSession()
        let url = URL(string: "https://developer.apple.com/test")!
        let response = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil)!
        session.stubbedResponse = response
        session.stubbedData = Data()

        let client = AppleDocumentationHTTPClient(session: session, retryDelayNanoseconds: 0, maxRetries: 3)
        do {
            _ = try await client.fetchWithRetry(url: url)
            Issue.record("Expected httpError(429) to be thrown.")
        } catch iDocsError.httpError(let statusCode) {
            #expect(statusCode == 429)
        } catch {
            Issue.record("Expected httpError(429), got \(error)")
        }
        #expect(session.requestCount == 3)
    }

    @Test("fetchWithRetry does not retry on 404")
    func fetchDoesNotRetryOn404() async throws {
        let session = MockNetworkSession()
        let url = URL(string: "https://developer.apple.com/test")!
        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
        session.stubbedResponse = response
        session.stubbedData = Data()

        let client = AppleDocumentationHTTPClient(session: session, retryDelayNanoseconds: 0, maxRetries: 3)
        do {
            _ = try await client.fetchWithRetry(url: url)
            Issue.record("Expected httpError(404) to be thrown.")
        } catch iDocsError.httpError(let statusCode) {
            #expect(statusCode == 404)
        } catch {
            Issue.record("Expected httpError(404), got \(error)")
        }
        #expect(session.requestCount == 1)
    }

    @Test("shouldRetry accurately identifies retryable conditions")
    func shouldRetryRules() {
        let client = AppleDocumentationHTTPClient(retryDelayNanoseconds: 0)

        #expect(!client.shouldRetry(after: CancellationError()))
        #expect(!client.shouldRetry(after: URLError(.cancelled)))
        #expect(client.shouldRetry(after: URLError(.timedOut)))
        #expect(client.shouldRetry(after: URLError(.networkConnectionLost)))
        #expect(client.shouldRetry(after: URLError(.cannotConnectToHost)))
        #expect(client.shouldRetry(after: iDocsError.httpError(statusCode: 403)))
        #expect(client.shouldRetry(after: iDocsError.httpError(statusCode: 429)))
        #expect(!client.shouldRetry(after: iDocsError.httpError(statusCode: 404)))
        #expect(!client.shouldRetry(after: iDocsError.httpError(statusCode: 500)))
        #expect(client.shouldRetry(after: iDocsError.maxRetriesReached))
    }

    @Test("fetchData builds data URL and fetches content")
    func fetchDataValidPath() async throws {
        let session = MockNetworkSession()
        let path = "/documentation/swiftui/view"
        let url = try #require(URLHelpers.dataURL(for: path))
        let payload = "{\"test\": true}".data(using: .utf8)!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        session.setResponse(for: url, data: payload, response: response)

        let client = AppleDocumentationHTTPClient(session: session, retryDelayNanoseconds: 0)
        let data = try await client.fetchData(for: path)
        #expect(data == payload)
    }
}
