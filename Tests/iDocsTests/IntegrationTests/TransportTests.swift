import Testing
import Foundation
import MCP
@testable import iDocs

@Suite("Transport Tests")
struct TransportTests {
    
    @Test("Argument parsing: default values")
    func testDefaultArgs() {
        let (mode, port) = iDocsServer.parseArgs(["iDocs"])
        #expect(mode == .stdio)
        #expect(port == 8080)
    }
    
    @Test("Argument parsing: HTTP mode")
    func testHTTPModeArg() {
        let (mode, port) = iDocsServer.parseArgs(["iDocs", "--http"])
        #expect(mode == .http)
        #expect(port == 8080)
    }
    
    @Test("Argument parsing: custom port")
    func testCustomPortArg() {
        let (mode, port) = iDocsServer.parseArgs(["iDocs", "--port", "9090"])
        #expect(port == 9090)
    }
    
    @Test("Argument parsing: HTTP and custom port")
    func testHTTPAndCustomPort() {
        let (mode, port) = iDocsServer.parseArgs(["iDocs", "--http", "--port", "1234"])
        #expect(mode == .http)
        #expect(port == 1234)
    }
}
