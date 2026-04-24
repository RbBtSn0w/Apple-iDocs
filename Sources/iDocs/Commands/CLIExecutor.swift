import Foundation
import iDocsAdapter

public enum CLIExecutor {
    @discardableResult
    public static func runSearch(
        query: String,
        outputFormat: CLIOutputFormat = .text,
        callerID: String? = nil
    ) async -> Int32 {
        let start = ContinuousClock.now
        do {
            let adapter = try CLIEnvironment.serviceFactory()
            let config = CLIEnvironment.configFactory().withInvocationContext(callerID: callerID)
            let results = try await adapter.search(query: query, config: config)
            let durationMs = durationInMilliseconds(since: start)
            let source = primarySource(from: results.map(\.source))

            if outputFormat == .json {
                return writeJSONPayload(
                    CLICommandPayload(
                        command: "search",
                        caller: callerID,
                        query: query,
                        id: nil,
                        category: nil,
                        source: source,
                        durationMs: durationMs,
                        resultCount: results.count,
                        selectedPaths: results.map(\.id),
                        exitCategory: .ok,
                        body: nil,
                        results: results.map {
                            CLISearchResultPayload(
                                id: $0.id,
                                title: $0.title,
                                snippet: $0.snippet,
                                technology: $0.technology,
                                source: $0.source?.rawValue
                            )
                        },
                        technologies: nil,
                        errorMessage: nil
                    )
                )
            }

            if results.isEmpty {
                CLIEnvironment.writeStdout("No matching documentation found.")
                return 0
            }

            var lines: [String] = ["### Apple Documentation Search Results", ""]
            for item in results {
                let source = item.source?.rawValue ?? "unknown"
                lines.append("- \(item.title) [\(item.technology)] {source: \(source)}")
                lines.append("  - ID: \(item.id)")
                if let snippet = item.snippet {
                    lines.append("  - Snippet: \(snippet)")
                }
            }
            CLIEnvironment.writeStdout(lines.joined(separator: "\n"))
            return 0
        } catch {
            let message = CLIErrorPresenter.message(for: error)
            let durationMs = durationInMilliseconds(since: start)
            if outputFormat == .json {
                _ = writeJSONPayload(
                    CLICommandPayload(
                        command: "search",
                        caller: callerID,
                        query: query,
                        id: nil,
                        category: nil,
                        source: nil,
                        durationMs: durationMs,
                        resultCount: 0,
                        selectedPaths: [],
                        exitCategory: CLIErrorPresenter.category(for: error),
                        body: nil,
                        results: [],
                        technologies: nil,
                        errorMessage: message
                    )
                )
            }
            CLIEnvironment.writeStderr(message)
            return 1
        }
    }

    @discardableResult
    public static func runFetch(
        id: String,
        outputFormat: CLIOutputFormat = .text,
        callerID: String? = nil
    ) async -> Int32 {
        let start = ContinuousClock.now
        do {
            let adapter = try CLIEnvironment.serviceFactory()
            let config = CLIEnvironment.configFactory().withInvocationContext(callerID: callerID)
            let content = try await adapter.fetch(id: id, config: config)
            let source = content.metadata["source"]
            let durationMs = durationInMilliseconds(since: start)

            if outputFormat == .json {
                return writeJSONPayload(
                    CLICommandPayload(
                        command: "fetch",
                        caller: callerID,
                        query: nil,
                        id: id,
                        category: nil,
                        source: source,
                        durationMs: durationMs,
                        resultCount: 1,
                        selectedPaths: [id],
                        exitCategory: .ok,
                        body: content.body,
                        results: nil,
                        technologies: nil,
                        errorMessage: nil
                    )
                )
            }

            if let source {
                CLIEnvironment.writeStdout("[source: \(source)]\n\(content.body)")
            } else {
                CLIEnvironment.writeStdout(content.body)
            }
            return 0
        } catch {
            let message = CLIErrorPresenter.message(for: error)
            let durationMs = durationInMilliseconds(since: start)
            if outputFormat == .json {
                _ = writeJSONPayload(
                    CLICommandPayload(
                        command: "fetch",
                        caller: callerID,
                        query: nil,
                        id: id,
                        category: nil,
                        source: nil,
                        durationMs: durationMs,
                        resultCount: 0,
                        selectedPaths: [],
                        exitCategory: CLIErrorPresenter.category(for: error),
                        body: nil,
                        results: nil,
                        technologies: nil,
                        errorMessage: message
                    )
                )
            }
            CLIEnvironment.writeStderr(message)
            return 1
        }
    }

    @discardableResult
    public static func runList(
        category: String?,
        outputFormat: CLIOutputFormat = .text,
        callerID: String? = nil
    ) async -> Int32 {
        let start = ContinuousClock.now
        do {
            let adapter = try CLIEnvironment.serviceFactory()
            let config = CLIEnvironment.configFactory().withInvocationContext(
                callerID: callerID,
                technologyCategoryFilter: category
            )
            let technologies = try await adapter.listTechnologies(config: config)
            let durationMs = durationInMilliseconds(since: start)

            if outputFormat == .json {
                return writeJSONPayload(
                    CLICommandPayload(
                        command: "list",
                        caller: callerID,
                        query: nil,
                        id: nil,
                        category: category,
                        source: technologies.isEmpty ? nil : "apple",
                        durationMs: durationMs,
                        resultCount: technologies.count,
                        selectedPaths: technologies.map(\.id),
                        exitCategory: .ok,
                        body: nil,
                        results: nil,
                        technologies: technologies.map {
                            CLITechnologyPayload(id: $0.id, name: $0.name, category: $0.category)
                        },
                        errorMessage: nil
                    )
                )
            }

            if technologies.isEmpty {
                CLIEnvironment.writeStdout("No technologies found in the catalog.")
                return 0
            }

            let lines = technologies.map { tech in
                if let category = tech.category {
                    return "- \(tech.name) (\(category)) [\(tech.id)]"
                }
                return "- \(tech.name) [\(tech.id)]"
            }
            CLIEnvironment.writeStdout(lines.joined(separator: "\n"))
            return 0
        } catch {
            let message = CLIErrorPresenter.message(for: error)
            let durationMs = durationInMilliseconds(since: start)
            if outputFormat == .json {
                _ = writeJSONPayload(
                    CLICommandPayload(
                        command: "list",
                        caller: callerID,
                        query: nil,
                        id: nil,
                        category: category,
                        source: nil,
                        durationMs: durationMs,
                        resultCount: 0,
                        selectedPaths: [],
                        exitCategory: CLIErrorPresenter.category(for: error),
                        body: nil,
                        results: nil,
                        technologies: [],
                        errorMessage: message
                    )
                )
            }
            CLIEnvironment.writeStderr(message)
            return 1
        }
    }

    private static func durationInMilliseconds(since start: ContinuousClock.Instant) -> Double {
        let duration = start.duration(to: ContinuousClock.now)
        return Double(duration.components.seconds) * 1_000
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000
    }

    private static func primarySource(from sources: [RetrievalSource?]) -> String? {
        let rawSources = Set(sources.compactMap { $0?.rawValue })
        guard !rawSources.isEmpty else { return nil }
        if rawSources.count == 1 {
            return rawSources.first
        }
        return "mixed"
    }

    @discardableResult
    private static func writeJSONPayload(_ payload: CLICommandPayload) -> Int32 {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        do {
            let data = try encoder.encode(payload)
            guard let text = String(data: data, encoding: .utf8) else {
                CLIEnvironment.writeStderr("Error [INTERNAL]: Failed to encode JSON output as UTF-8.")
                return 1
            }
            CLIEnvironment.writeStdout(text)
            return payload.exitCategory == .ok ? 0 : 1
        } catch {
            CLIEnvironment.writeStderr("Error [INTERNAL]: Failed to encode JSON output.")
            return 1
        }
    }
}
