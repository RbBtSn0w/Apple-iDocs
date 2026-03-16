# Data Model: Three-Layer Architecture Refactoring

## Overview
This document defines the core data structures used in the `iDocsKit` (Common) and `iDocsAdapter` (Adapter) layers. These models are designed to be shared across Application layers (CLI, App) to ensure consistency.

## 1. Configuration (Injected via Adapter)

### `DocumentationConfig`
- **Fields**:
  - `cachePath: String`: Path to the local DiskCache directory.
  - `locale: Locale`: The target language/locale for documentation.
  - `timeout: TimeInterval`: Network timeout for remote requests.
  - `apiBaseURL: URL`: Base URL for Apple documentation API (default: official).
  - `enableFileLocking: Bool`: Defaults to false. When true, the Common layer uses advisory file locks for disk cache writes (intended only for explicitly shared-cache setups, e.g., App Groups).
- **Rationale**: Decouples the Common layer from environment-specific configuration.

## 2. Core Entities

### `DocumentationContent`
- **Fields**:
  - `title: String`: The title of the document.
  - `body: String`: Rendered Markdown body.
  - `metadata: [String: String]`: Key-value pairs of document metadata (e.g., platforms, versions).
  - `url: URL`: The source URL of the document.
- **Relationships**: A document may contain an array of `ContentSection` entities.

### `SearchResult`
- **Fields**:
  - `id: String`: Unique identifier for the documentation item.
  - `title: String`: Matching title.
  - `snippet: String?`: Preview snippet highlighting the match.
  - `technology: String`: The technology name (e.g., "SwiftUI").

### `Technology`
- **Fields**:
  - `name: String`: Display name.
  - `id: String`: Internal identifier used for fetching.
  - `category: String?`: Optional grouping (e.g., "Frameworks").

## 3. Errors and State

### `DocumentationError`
- **Cases**:
  - `.notFound(id: String)`: Document or technology not found.
  - `.networkError(Error)`: Low-level transport failure.
  - `.parsingError(reason: String)`: Failed to decode DocC JSON or other data.
  - `.unauthorized`: Credential failure (if applicable).
  - `.internalError(message: String)`: Logic or environment failure (e.g., file lock failure).

### `CacheState`
- **States**:
  - `.stale`: Cache exists but is beyond TTL.
  - `.fresh`: Cache is valid and can be served immediately.
  - `.missing`: No local data available.
