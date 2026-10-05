# Implementation Plan - DocC Lists Ingestion and Bounded Search Ranking

## Proposed Changes

### 1. Ingestion & Rendering
- **`AppleDocCBlockContentParser.swift`**:
  - Extend item parsing from `.array` only to handle `.object` containing `content` arrays, single typed block objects, and defensive `.string` unwrapping.

### 2. Search Intent & Ranking
- **`SearchQueryIntent.swift`**:
  - Add `app`, `apps` to `stopWords`.
  - Check boundary-safe Xcode technology prefix matching using `DocumentationPath.make("xcode")`.
  - Update `SearchResultRanker` to pre-calculate scores in a single $O(N)$ pass, deduplicate paths, filter breadcrumb `/documentation/technologies`, and limit results to 50 items.

### 3. Apple Remote API & Concurrency
- **`AppleDocumentationHTTPClient.swift`**:
  - Isolated network transport, User-Agent pool rotation, OpenTelemetry tracing, and exponential backoff retry logic.
  - Configurable `retryDelayNanoseconds` (defaulting to 0 in testing environments) eliminating artificial sleep in mock test runs.
- **`AppleRemoteSearchCrawler.swift`**:
  - Encapsulated documentation search index parsing, technology graph traversal, Xcode subgroup crawling, and multi-candidate `documentKind` inference.
- **`AppleJSONAPI.swift`**:
  - Refactored as backward-compatible coordinator delegating transport to `AppleDocumentationHTTPClient` and search traversal to `AppleRemoteSearchCrawler`.

### 4. Verification Suites
- **Unit Tests**: `AppleDocCIngestionTests.swift`, `SearchDocsToolDeduplicationTests.swift`, `SearchRelevanceProfileTests.swift`, `AppleDocumentationHTTPClientTests.swift`, `AppleRemoteSearchCrawlerTests.swift`.
- **Integration Tests**: `NetworkToolTests.swift`, `SearchDocsTool Integration Tests` (optimized from ~38s to ~1.2s).
- **E2E Regressions**: `scripts/tests/e2e-issues-regression.test.sh`, `scripts/e2e-cli.sh`.
