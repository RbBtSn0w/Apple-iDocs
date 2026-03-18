# Data Model: CLI Multi-Source Retrieval

## Overview

This feature introduces explicit retrieval-source modeling to support deterministic chain behavior and observability.

## Entities

### RetrievalSource
- **Purpose**: Enumerates the layer that produced a successful result.
- **Values**:
  - `cache`
  - `local`
  - `apple`
  - `sosumi`

### SourcePolicy
- **Purpose**: Defines ordered retrieval layers per operation.
- **Fields**:
  - `operation: search | fetch`
  - `orderedLayers: [RetrievalSource]`
- **Rules**:
  - `search`: cache/local/apple/sosumi (cache may be memory)
  - `fetch`: cache/local/apple/sosumi (cache may be memory+disk)

### SearchResult (Adapter-facing)
- **Purpose**: User-visible search output entity.
- **Fields**:
  - `id: String`
  - `title: String`
  - `snippet: String?`
  - `technology: String`
  - `source: RetrievalSource?`
- **Validation**:
  - `id` non-empty
  - `source` must be one of allowed values when present

### DocumentationContent (Adapter-facing)
- **Purpose**: User-visible fetched content entity.
- **Fields**:
  - `title: String`
  - `body: String`
  - `metadata: [String: String]` (includes source hit)
  - `url: URL`
- **Validation**:
  - `body` non-empty on success
  - `metadata["source"]` present on success

### FallbackAttempt
- **Purpose**: Internal execution trace concept for testing and diagnostics.
- **Fields**:
  - `operation`
  - `source`
  - `outcome: hit | miss | error`

## State Transitions

### Search
1. Start with local/cache candidates.
2. On miss, try Apple remote.
3. On Apple miss/error, try sosumi remote.
4. Return first successful non-empty result set or standardized not-found/network error.

### Fetch
1. Try cache.
2. Try local Xcode.
3. Try Apple remote.
4. On Apple miss/error, try sosumi remote markdown/content path.
5. Return first successful content or standardized terminal error.
