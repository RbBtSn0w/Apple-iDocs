import Foundation

enum IntegrationTestGate {
    static let environmentKey = "IDOCS_INTEGRATION_TESTS"
    
    static var isEnabled: Bool {
        if ProcessInfo.processInfo.environment[environmentKey] == "1" {
            return true
        }
        if isFilterEnabled() {
            return true
        }
        return false
    }
    
    static var disabledReason: String {
        "Integration tests disabled. Set IDOCS_INTEGRATION_TESTS=1 or run swift test --filter IntegrationTests."
    }
    
    private static func isFilterEnabled() -> Bool {
        let env = ProcessInfo.processInfo.environment
        if let filter = env["SWIFT_TEST_FILTER"], filter.contains("IntegrationTests") {
            return true
        }
        if let filter = env["TEST_FILTER"], filter.contains("IntegrationTests") {
            return true
        }
        if let filter = env["XCTestFilter"], filter.contains("IntegrationTests") {
            return true
        }
        let args = ProcessInfo.processInfo.arguments
        return args.contains("IntegrationTests") || args.joined(separator: " ").contains("IntegrationTests")
    }
}
