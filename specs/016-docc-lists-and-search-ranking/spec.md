# Feature Specification: DocC Lists Ingestion and Bounded Search Ranking

**Feature Branch**: `review_latest_github_issues`
**Created**: 2026-10-05
**Status**: Completed
**Input**: GitHub Issues #53 & #54 feedback:
- Issue #53: `idocs fetch` dropped list items in DocC rendering (e.g. release notes bullet points missing).
- Issue #54: `idocs search` returned duplicate `/documentation/technologies` entries, lacked Xcode guide recall ("localizing your app using agents", "String Catalog"), and emitted stderr cancellation noise (`Attempt 1 failed with error: cancelled`).

## User Scenarios & Testing

### User Story 1 - Fetch DocC Release Notes with Preserved List Items & Tables (Priority: P1)

As an agent querying Apple release notes and guide documentation via `idocs fetch`, I need all ordered and unordered list items and tables to be rendered in markdown without dropped content, so that bullet points and key information are not lost.

**Acceptance Criteria**:
1. When Apple DocC returns items wrapped in `{ "content": [...] }` or raw strings, `AppleDocCBlockContentParser` normalizes each item into `[ContentBlock]` instead of dropping it with a diagnostic.
2. In markdown output, bullet points are rendered with standard `- ` list prefixes, and numbered items with `1. ` prefixes.
3. Diagnostic events no longer report `content_blocks_not_array` or `block_items_not_array` on standard Apple list/table payloads.

---

### User Story 2 - Recall Xcode Guides and Bound Search Results (Priority: P1)

As an agent using `idocs search`, I need guide queries such as "localizing your app using agents" and "String Catalog" to recall the relevant Xcode documentation articles with bounded, deduplicated results, without stderr cancellation noise.

**Acceptance Criteria**:
1. Search intent expands stopwords to include generic terms like `app` and `apps`, enabling accurate matching on `localizing` and `agents`.
2. Technology prefix checking strictly validates segment boundaries via `DocumentationPath.make("xcode")` to prevent false positive matches on unrelated technologies like `/documentation/xcodekit`.
3. Candidate search results deduplicate by normalized path, keeping the highest-scoring match and capping the result list to 50 items.
4. Redundant breadcrumb `/documentation/technologies` is excluded unless the query explicitly targets technologies.
5. Sibling concurrent task cancellations do not log `Attempt 1 failed with error: cancelled` to stderr.
