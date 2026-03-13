import Foundation
import Logging
import MCP

public struct BrowseTechnologiesTool {
    private let logger = Logger(label: "com.snow.idocs-browse-tech")
    private let api = AppleJSONAPI()
    
    public init() {}
    
    public func run() async throws -> String {
        logger.info("Browsing Apple technologies catalog...")
        
        let technologies = try await api.fetchTechnologies()
        return formatTechnologies(technologies)
    }
    
    private func formatTechnologies(_ technologies: [Technology]) -> String {
        if technologies.isEmpty {
            return "No technologies found in the catalog."
        }
        
        var output = "### Apple Technologies Catalog\n\n"
        for tech in technologies {
            output += "- **\(tech.name)** (\(tech.kind))\n"
            output += "  - Path: `\(tech.url)`\n"
        }
        return output
    }
}
