# Feature Specification: Search and Fetch Reliability for Mixed Apple Documentation Sources

**Feature Branch**: `011-search-fetch-reliability`  
**Created**: Monday, May 11, 2026  
**Status**: Verified
**Input**: User description: "GitHub issue #8: Improve idocs search/fetch reliability for mixed Apple documentation sources"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Understand Mixed Search Results Before Fetching (Priority: P1)

As an agent or developer using `idocs search`, I want every search result to clearly describe what kind of Apple page it represents and whether it can be fetched by `idocs fetch`, so I can choose usable evidence without wasting time on unsupported links.

**Why this priority**: `apple-skills` depends on the `idocs search -> idocs fetch` evidence path for Apple-fact claims. When search returns Help, video, news, marketing, or broad App Store Connect pages that fetch cannot retrieve, agents lose the evidence path or fall back to generic web browsing manually.

**Independent Test**: Can be tested by running a broad Apple query that returns mixed Apple page families and verifying each result exposes a stable source kind, fetchability status, and enough provenance to explain why the result is or is not usable by `idocs fetch`.

**Acceptance Scenarios**:

1. **Given** a broad query such as `idocs search "Xcode Cloud TestFlight App Store Connect"`, **When** results include documentation, Help, video, news, marketing, or unknown page families, **Then** every result is classified with a source kind such as `documentation`, `help`, `video`, `news`, `marketing`, or `unknown`.
2. **Given** a search result points to a page family that `idocs fetch` can retrieve, **When** the result is shown, **Then** the result indicates that fetch is supported.
3. **Given** a search result points to a page family that `idocs fetch` cannot retrieve, **When** the result is shown, **Then** the result indicates that fetch is unsupported before the user attempts a fetch.
4. **Given** a long natural-language query produces no Apple remote results but useful fallback results, **When** fallback search results are shown, **Then** users can tell which query attempt produced each result.

---

### User Story 2 - Fetch App Store Connect Help Evidence Reliably (Priority: P1)

As an agent or developer researching App Store, TestFlight, or Xcode Cloud workflows, I want `idocs fetch` to retrieve App Store Connect Help articles when search returns those Help paths, so Apple Help pages remain part of the normal evidence path.

**Why this priority**: App Store Connect Help pages are real Apple pages and are important for App Store and TestFlight workflows. Treating them as missing documentation creates misleading failures and breaks evidence collection.

**Independent Test**: Can be tested by fetching known App Store Connect Help paths returned by search and verifying the command either returns readable article content or reports an explicit unsupported-source error rather than `NOT_FOUND`.

**Acceptance Scenarios**:

1. **Given** search returns `/help/app-store-connect/manage-builds/upload-builds`, **When** I run `idocs fetch /help/app-store-connect/manage-builds/upload-builds`, **Then** the command retrieves a readable Help article with title, headings, body content, and source URL, or clearly reports that this source type is unsupported.
2. **Given** search returns `/help/app-store-connect/test-a-beta-version/testflight-overview`, **When** I run `idocs fetch /help/app-store-connect/test-a-beta-version/testflight-overview`, **Then** the command retrieves the Help article or clearly reports that this source type is unsupported.
3. **Given** a path maps to a real Apple Help article, **When** it is fetched, **Then** the source URL resolves to the corresponding `developer.apple.com/help/app-store-connect/...` article path.
4. **Given** a path such as `/app-store-connect/api`, `/news`, or `/videos/...` is not supported, **When** it is fetched, **Then** the command returns an unsupported-source classification rather than a misleading documentation-not-found result.

---

### User Story 3 - Preserve Fallback Provenance for Fetch Results (Priority: P1)

As an agent or developer using fetched Apple documentation as evidence, I want fetch output and diagnostics to show which source succeeded and which prior sources failed, so I can judge the reliability of the evidence and debug source-specific failures.

**Why this priority**: Some standard-looking `/documentation/...` pages fail in Apple remote fetch decoding but succeed through fallback. Without provenance, users cannot tell whether content came from Apple JSON, fallback extraction, or another source.

**Independent Test**: Can be tested by fetching standard documentation paths that trigger primary-source decode failures and verifying successful fallback output records both the failed primary attempt and the successful fallback source.

**Acceptance Scenarios**:

1. **Given** Apple remote fetch cannot decode `/documentation/xcode/creating-a-workflow-that-builds-your-app-for-distribution`, **When** fallback content is returned, **Then** the final output preserves the failed primary-source category and the successful fallback source.
2. **Given** Apple remote fetch cannot decode `/documentation/xcode/developing-a-workflow-strategy-for-xcode-cloud`, **When** fallback content is returned, **Then** the final output records that fallback provenance.
3. **Given** Apple remote fetch cannot decode `/documentation/xcode/environment-variable-reference`, **When** fallback content is returned, **Then** users can tell that the successful content did not come directly from the primary Apple remote fetch.
4. **Given** a fetch attempt fails across multiple sources, **When** the final error is shown, **Then** the error lists all attempted sources in order with a category for each failure.

---

### User Story 4 - Surface Local Documentation Cache Degradation (Priority: P2)

As an agent or developer running `idocs search`, I want missing local Xcode documentation to be reported as actionable capability degradation, so I understand that lookup quality and latency now depend on remote sources.

**Why this priority**: Missing local documentation is not fatal, but it changes the behavior and reliability profile of every lookup. Agents need to classify this condition instead of treating it as an incidental warning.

**Independent Test**: Can be tested by running search with a nonexistent local Xcode documentation cache path and verifying the command continues to remote sources while exposing structured degradation information.

**Acceptance Scenarios**:

1. **Given** the local Xcode documentation cache is unavailable at a path such as `/Users/snow/Library/Developer/Xcode/DocumentationCache`, **When** I run `idocs search`, **Then** the search continues through remote sources instead of failing.
2. **Given** local documentation is unavailable, **When** search output or diagnostics are produced, **Then** callers can classify local docs as unavailable, for example through a `local_docs_available: false` style signal or equivalent machine-readable diagnostic.
3. **Given** local documentation is unavailable, **When** the user sees diagnostics, **Then** the message explains that the current run is remote-only and gives an actionable path to restore or understand local documentation availability.

---

### User Story 5 - Normalize Broad Queries Without Hiding the Original Query (Priority: P3)

As an agent or developer entering broad natural-language Apple documentation queries, I want `idocs search` to preserve the original query while also trying a more focused keyword-oriented query when helpful, so broad questions still find relevant Apple pages without losing traceability.

**Why this priority**: Broad queries such as `Xcode Cloud TestFlight App Store Connect` can return no primary Apple remote results while fallback sources contain useful workflow docs and Help pages. Users need both better recall and clear query provenance.

**Independent Test**: Can be tested by running a broad query and verifying the command exposes the original query, any derived keyword query attempts, and which attempt produced each result.

**Acceptance Scenarios**:

1. **Given** a broad natural-language query returns no primary Apple remote results, **When** fallback query attempts produce useful results, **Then** results identify the original and derived query attempts.
2. **Given** a derived keyword query is used, **When** results are shown, **Then** the original user query remains visible for traceability.
3. **Given** both original and derived query attempts produce results, **When** results are ranked or displayed, **Then** duplicate or conflicting entries do not obscure the source kind and fetchability metadata.

### Edge Cases

- The local Xcode documentation cache is missing or empty; search must continue remotely while reporting local-source degradation.
- Apple remote search returns no results; fallback search must be attempted and labeled clearly.
- Search results include a mix of `/documentation/...`, `/help/...`, `/videos/...`, `/news`, `/app-store-connect/...`, marketing pages, and unknown paths.
- Apple remote fetch returns unreadable or schema-incompatible data for a documentation path; fallback must be attempted and the decode failure category preserved.
- Apple remote fetch fails and fallback returns an HTTP 500; the final error must show both failure categories in source-attempt order.
- App Store Connect Help paths are real Apple pages but may not share the same fetch mechanism as standard documentation pages.
- Unsupported Apple page families must be classified as unsupported, not as missing documentation.
- Diagnostics must avoid dumping full raw remote payloads by default while still exposing enough sanitized metadata to debug failures.
- Existing CLI-first behavior must remain intact: `search`, `fetch`, and `list` stay stateless, and web browsing remains a deliberate fallback only for unsupported Apple page families.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `idocs search` MUST classify each result by source kind, including at least documentation, Help, video, news, marketing, and unknown categories.
- **FR-002**: `idocs search` MUST indicate whether each result is expected to be fetchable by `idocs fetch`.
- **FR-003**: `idocs search` MUST preserve source provenance for mixed results, including whether a result came from primary Apple remote search, fallback search, or another configured source in the lookup chain.
- **FR-004**: `idocs search` MUST report missing local Xcode documentation as capability degradation while continuing to remote sources.
- **FR-005**: Missing local documentation diagnostics MUST be actionable and machine-readable enough for agents to classify remote-only behavior.
- **FR-006**: `idocs search` MUST support broad natural-language queries by preserving the original query and SHOULD attempt query normalization (e.g., keyword-oriented fallback) to improve recall, exposing which query attempt produced each result.
- **FR-007**: `idocs fetch` MUST preserve ordered source-attempt provenance for every fetch, including both failed attempts and the successful source when one succeeds.
- **FR-008**: Apple remote fetch decode failures MUST be categorized distinctly from not-found, unsupported-source, malformed-response, and network failures.
- **FR-009**: Fetch diagnostics for remote failures MUST include sanitized debugging metadata such as status category, content type when known, and source family when available, without exposing full raw payloads by default.
- **FR-010**: `idocs fetch` MUST retrieve App Store Connect Help articles returned by search, including `/help/app-store-connect/manage-builds/upload-builds` and `/help/app-store-connect/test-a-beta-version/testflight-overview`. If retrieval fails or is not yet implemented, it MUST explicitly classify them as `unsupported_source_type` or `fetch_failed` rather than `NOT_FOUND`.
- **FR-011**: Fetched App Store Connect Help content MUST include the article title, headings, readable article body, and source URL when retrieval succeeds.
- **FR-012**: Unsupported paths such as `/videos/...`, `/news`, and unsupported `/app-store-connect/...` pages MUST return an unsupported-source classification rather than `NOT_FOUND`.
- **FR-013**: Aggregate fetch failures MUST show all attempted sources in order, with a stable failure category for each source attempt.
- **FR-014**: The `idocs search -> idocs fetch` contract MUST remain the primary evidence path for Apple documentation claims used by agents and skills.
- **FR-015**: Existing supported standard `/documentation/...` search and fetch behavior MUST continue to work while adding classification, fetchability, and provenance metadata.
- **FR-016**: The feature MUST cover the observed commands from issue #8: `idocs search "Xcode Cloud TestFlight App Store Connect"`, `idocs fetch /documentation/xcode/creating-a-workflow-that-builds-your-app-for-distribution`, `idocs fetch /documentation/xcode/developing-a-workflow-strategy-for-xcode-cloud`, `idocs fetch /documentation/xcode/environment-variable-reference`, `idocs fetch /help/app-store-connect/manage-builds/upload-builds`, `idocs fetch /help/app-store-connect/test-a-beta-version/testflight-overview`, `idocs fetch /app-store-connect/api`, and `idocs fetch /documentation/appstoreconnectapi`.
- **FR-017**: `idocs fetch` SHOULD provide a targeted fetch path or improved diagnostics for App Store Connect API overview pages to avoid generic failures when primary remote fetch and general fallback both fail.

### Key Entities

- **Search Result**: A returned Apple page candidate with title, path or URL, source kind, fetchability status, source provenance, and query-attempt provenance.
- **Source Kind**: A user-facing classification for Apple page families, including documentation, Help, video, news, marketing, and unknown.
- **Fetch Capability**: A declaration of whether a search result is expected to be retrievable by `idocs fetch`.
- **Source Attempt**: One ordered attempt to search or fetch from a specific source, with source family, status category, and sanitized diagnostic metadata.
- **Fallback Provenance**: The record showing which sources failed, which source succeeded, and how the final result was obtained.
- **Capability Degradation**: A non-fatal condition, such as unavailable local Xcode documentation, that changes lookup quality, latency, or recall.
- **Query Attempt**: The original user query or a derived keyword-oriented query attempted during search, used to explain result provenance.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of search results returned for `idocs search "Xcode Cloud TestFlight App Store Connect"` include source kind and fetchability information.
- **SC-002**: 100% of unsupported mixed Apple page families returned by search are marked unsupported before a user attempts to fetch them.
- **SC-003**: Fetching `/help/app-store-connect/manage-builds/upload-builds` and `/help/app-store-connect/test-a-beta-version/testflight-overview` either returns readable Help article content or returns an explicit unsupported-source classification, with no misleading `NOT_FOUND` result for real but unsupported Apple page families.
- **SC-004**: 100% of fetches that use fallback after a primary-source decode failure expose both the failed primary-source category and the successful fallback source.
- **SC-005**: 100% of aggregate fetch failures expose an ordered source-attempt summary with stable categories such as primary decode failure, fallback HTTP 500, unsupported source type, or not found.
- **SC-006**: Searches run without a local Xcode documentation cache still complete through remote sources and expose a machine-readable remote-only degradation signal.
- **SC-007**: Broad-query fallback search preserves the original query and identifies any derived query that produced results.
- **SC-008**: Existing successful `/documentation/...` search and fetch flows remain compatible while adding source classification, fetchability, and provenance metadata.
- **SC-009**: Agent workflows can continue to use `idocs search -> idocs fetch` as the default Apple evidence path, with generic web browsing reserved for explicitly unsupported Apple page families.

## Source Coverage Traceability

- **Issue summary**: Covered by User Stories 1-5, FR-001 through FR-016, and SC-001 through SC-009.
- **Case 1, missing local Xcode documentation cache**: Covered by User Story 4, Edge Cases, FR-004, FR-005, SC-006.
- **Case 2, broad Apple/Xcode Cloud query and sosumi fallback**: Covered by User Stories 1 and 5, FR-001, FR-002, FR-003, FR-006, SC-001, SC-002, SC-007.
- **Case 3, Apple remote fetch decode failures on documentation paths**: Covered by User Story 3, FR-007, FR-008, FR-009, FR-016, SC-004.
- **Case 4, search returns App Store Connect Help paths that fetch cannot retrieve**: Covered by User Story 2, FR-010, FR-011, FR-012, FR-016, SC-003.
- **Case 5, fallback HTTP 500 for documentation roots**: Covered by User Story 3, Edge Cases, FR-013, FR-016, SC-005.
- **Proposed implementation direction**: Captured as product requirements for source-kind classification, fetchability metadata, Help-page coverage or unsupported-source classification, query-attempt provenance, and machine-readable diagnostics without prescribing internal implementation.
- **Proposed test coverage**: Reflected in independent tests, acceptance scenarios, edge cases, functional requirements, and success criteria for fallback order, local-cache degradation, mixed result classification, fetchability, decode fallback, fallback HTTP 500, App Store Connect Help retrieval, unsupported source classification, and long-query provenance.
- **Acceptance criteria from issue #8**: Explicitly verified by SC-001 (classification), SC-003 (Help retrieval/classification), SC-004 (decode fallback provenance), SC-005 (aggregate failures), and SC-009 (CLI-first contract).
- **Suggested Tests from issue #8**:
    - Case 1 (Local cache): Covered by Scenario 4.1-3.
    - Case 2 (Broad query): Covered by Scenario 1.1-4 and Scenario 5.1-3.
    - Case 3 (Decode failure): Covered by Scenario 3.1-4.
    - Case 4 (Help fetch): Covered by FR-011 and Scenario 2.1-4.
    - Case 5 (Aggregate/500): Covered by SC-005 and FR-013.
