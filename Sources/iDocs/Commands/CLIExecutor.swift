import Foundation
import iDocsAdapter

public enum CLIExecutor {
    @discardableResult
    public static func runSearch(query: String) async -> Int32 {
        do {
            let adapter = try CLIEnvironment.serviceFactory()
            let config = CLIEnvironment.configFactory()
            let results = try await adapter.search(query: query, config: config)

            if results.isEmpty {
                CLIEnvironment.writeStdout("No matching documentation found.")
                return 0
            }

            var lines: [String] = ["### Apple Documentation Search Results", ""]
            for item in results {
                lines.append("- \(item.title) [\(item.technology)]")
                lines.append("  - ID: \(item.id)")
                if let snippet = item.snippet {
                    lines.append("  - Snippet: \(snippet)")
                }
            }
            CLIEnvironment.writeStdout(lines.joined(separator: "\n"))
            return 0
        } catch {
            CLIEnvironment.writeStderr(CLIErrorPresenter.message(for: error))
            return 1
        }
    }

    @discardableResult
    public static func runFetch(id: String) async -> Int32 {
        do {
            let adapter = try CLIEnvironment.serviceFactory()
            let config = CLIEnvironment.configFactory()
            let content = try await adapter.fetch(id: id, config: config)
            CLIEnvironment.writeStdout(content.body)
            return 0
        } catch {
            CLIEnvironment.writeStderr(CLIErrorPresenter.message(for: error))
            return 1
        }
    }

    @discardableResult
    public static func runList(category: String?) async -> Int32 {
        do {
            let adapter = try CLIEnvironment.serviceFactory()
            let config = CLIEnvironment.configFactory()
            let technologies = try await adapter.listTechnologies(config: config)
            let filtered = technologies.filter { tech in
                guard let category else { return true }
                return tech.category?.localizedCaseInsensitiveContains(category) == true
            }

            if filtered.isEmpty {
                CLIEnvironment.writeStdout("No technologies found in the catalog.")
                return 0
            }

            let lines = filtered.map { tech in
                if let category = tech.category {
                    return "- \(tech.name) (\(category)) [\(tech.id)]"
                }
                return "- \(tech.name) [\(tech.id)]"
            }
            CLIEnvironment.writeStdout(lines.joined(separator: "\n"))
            return 0
        } catch {
            CLIEnvironment.writeStderr(CLIErrorPresenter.message(for: error))
            return 1
        }
    }
}
