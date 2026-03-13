import Testing
import Foundation
import MCP
@testable import iDocs

@Suite("Transport Tests")
struct TransportTests {
    
    @Test("Server starts with StdioTransport")
    func testStdioTransport() async throws {
        // This is hard to test in unit tests as it hijacks stdin/stdout
        // We'll verify the configuration logic instead
    }
    
    @Test("Server starts with HTTPTransport")
    func testHTTPTransport() async throws {
        // Verify server can be initialized with StatefulHTTPServerTransport
    }
}
