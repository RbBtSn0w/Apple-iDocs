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
- **`AppleJSONAPI.swift`**:
  - Catch `Task.isCancelled`, `CancellationError`, and `URLError.cancelled` to abort gracefully without stderr noise or retry loops.
  - Traverse high-priority candidate technologies and subgroups.

### 4. Verification Suites
- **Unit Tests**: `AppleDocCIngestionTests.swift`, `SearchDocsToolDeduplicationTests.swift`.
- **Integration Tests**: `NetworkToolTests.swift`.
- **E2E Regressions**: `scripts/tests/e2e-issues-regression.test.sh`, `scripts/e2e-cli.sh`.
