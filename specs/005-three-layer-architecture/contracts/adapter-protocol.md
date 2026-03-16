# Contract: DocumentationService Protocol (Adapter)

## Overview
This contract defines the public interface of the `iDocsAdapter` layer. Any Application layer (CLI, App) MUST use this protocol to interact with the documentation engine.

## `DocumentationService` (Protocol)

```swift
public protocol DocumentationService: Sendable {
    /// Searches for documentation across available sources.
    /// - Parameters:
    ///   - query: The search term (supports wildcards).
    ///   - config: The environment-specific configuration (cache path, locale, etc).
    /// - Returns: An array of search results matching the query.
    func search(query: String, config: DocumentationConfig) async throws -> [SearchResult]

    /// Fetches the full content of a documentation item by its unique ID.
    /// - Parameters:
    ///   - id: The documentation identifier.
    ///   - config: The environment-specific configuration.
    /// - Returns: The rendered documentation content.
    func fetch(id: String, config: DocumentationConfig) async throws -> DocumentationContent

    /// Lists all available technologies (frameworks/SDKs).
    /// - Parameters:
    ///   - config: The environment-specific configuration.
    /// - Returns: An array of technology identifiers and metadata.
    func listTechnologies(config: DocumentationConfig) async throws -> [Technology]
    
    /// Provides the current version of the underlying Common layer.
    func getCoreVersion() -> String
}
```

## `DocumentationLogger` (Protocol)

```swift
public protocol DocumentationLogger: Sendable {
    func log(level: LogLevel, message: String, context: [String: Any]?)
}

public enum LogLevel {
    case debug, info, warning, error
}
```
