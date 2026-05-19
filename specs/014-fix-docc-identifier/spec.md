# Feature Specification: Robust DocC Identifier Fetch

**Feature Branch**: `014-fix-docc-identifier`  
**Created**: 2026-05-18  
**Status**: Verified
**Input**: User description: "Fix `idocs fetch` when current Apple DocC content represents `identifier` as an object containing a URL instead of the older string form. Preserve the public content shape, cache stability, source ordering, and fallback diagnostics."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fetch Current Apple DocC Content (Priority: P1)

As an agent using iDocs for Apple documentation evidence, I need `idocs fetch` to accept current Apple DocC content whose identifier is represented as structured metadata, so that reachable official Apple documentation is returned directly instead of being treated as a decode failure.

**Why this priority**: This restores the primary evidence path for Apple-hosted documentation pages that are currently reachable but incorrectly rejected.

**Independent Test**: Can be tested by simulating a cache miss and local miss where Apple returns a valid documentation payload with an object-shaped identifier, then confirming the fetch result is sourced from Apple and no fallback source is used.

**Acceptance Scenarios**:

1. **Given** no cached or local documentation exists for a requested Apple documentation path, **When** Apple returns a valid documentation payload whose identifier contains a URL value, **Then** the fetch succeeds with Apple as the selected source.
2. **Given** the same Apple response, **When** source attempts are reported, **Then** the attempts are limited to cache, local, and Apple in that order.
3. **Given** Apple returns valid documentation with an object-shaped identifier, **When** the caller inspects the returned content, **Then** the externally visible identifier remains the canonical URL string.

---

### User Story 2 - Preserve Existing Identifier Compatibility (Priority: P2)

As a maintainer of iDocs cache files and fixtures, I need existing content that uses string identifiers to remain valid and stable, so that this bug fix does not invalidate stored data or existing tests.

**Why this priority**: Compatibility protects existing users and keeps the fix narrowly scoped to the newly observed Apple payload shape.

**Independent Test**: Can be tested by fetching or loading documentation content whose identifier is already a string and confirming the result remains unchanged.

**Acceptance Scenarios**:

1. **Given** documentation content contains a string identifier, **When** the content is read and later stored again, **Then** the identifier remains a string with the same value.
2. **Given** existing tests and fixtures use string identifiers, **When** the fetch test suite runs, **Then** those fixtures continue to pass without fixture format migration.

---

### User Story 3 - Keep Invalid Remote Content Diagnosable (Priority: P3)

As an iDocs maintainer, I need malformed Apple documentation payloads to continue producing explicit remote decode diagnostics and fallback behavior, so that genuine upstream schema problems remain visible.

**Why this priority**: The fix must not turn invalid Apple responses into silent or misleading successes.

**Independent Test**: Can be tested by simulating Apple documentation content with malformed or incomplete identifier data and confirming the Apple attempt records a decode failure before fallback handling continues.

**Acceptance Scenarios**:

1. **Given** Apple returns documentation content whose structured identifier lacks a URL value, **When** `idocs fetch` processes the response, **Then** the Apple attempt is recorded as a remote decode failure.
2. **Given** Apple returns otherwise invalid documentation content, **When** `idocs fetch` processes the response, **Then** existing fallback behavior remains available and diagnostic reporting still identifies the remote decode failure.

### Edge Cases

- Apple documentation content provides an identifier as a string: fetch behavior and stored output remain unchanged.
- Apple documentation content provides an identifier as structured metadata with a URL and optional additional fields: the URL is treated as the canonical identifier and additional fields do not alter the public content shape.
- Apple documentation content provides structured identifier metadata without a URL: the response is rejected as malformed and reported through the existing remote decode diagnostic path.
- Apple documentation content is invalid for reasons unrelated to the identifier: existing decode failure and fallback behavior remains unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST accept Apple documentation content where the identifier is provided as a string.
- **FR-002**: The system MUST accept Apple documentation content where the identifier is provided as structured metadata containing a URL.
- **FR-003**: When structured identifier metadata is accepted, the externally visible identifier MUST be the URL string from that metadata.
- **FR-004**: The system MUST reject structured identifier metadata that does not contain a URL value and report it through the same remote decode failure diagnostic path used for invalid Apple documentation content.
- **FR-005**: The system MUST preserve existing fetch source ordering: cache, local content, Apple, then fallback sources only when needed.
- **FR-006**: When Apple returns valid documentation content with a structured identifier, the system MUST NOT attempt fallback sources after the Apple source succeeds.
- **FR-007**: Stored documentation content emitted by iDocs MUST continue to represent the identifier as a string, preserving existing cache and fixture compatibility.
- **FR-008**: The system MUST preserve existing behavior for invalid Apple documentation content unrelated to identifier shape, including remote decode diagnostics and fallback attempts.
- **FR-009**: The change MUST NOT alter the public documentation content fields available to callers.

#### iDocs Constitution Alignment

- This feature touches `fetch` as the primary capability.
- The feature restores fetch-backed Apple documentation evidence when official Apple content is reachable but uses the current identifier shape.
- CLI output compatibility is required: existing optional JSON fields, source reporting, and diagnostic semantics must remain stable.
- No new runtime dependency is required; the shipped CLI remains free of Node, Python, or MCP runtime coupling.

### Key Entities

- **Documentation Content**: The fetched Apple documentation page content returned to callers, including its externally visible identifier string.
- **Identifier Metadata**: The upstream identifier representation supplied by Apple documentation content, either as a direct string or as structured metadata containing a URL.
- **Fetch Source Attempt**: A recorded attempt to retrieve documentation from cache, local content, Apple, or a fallback source, including success and diagnostic state.
- **Remote Decode Diagnostic**: The diagnostic result used when Apple documentation content is reachable but cannot be accepted as valid documentation content.

### Assumptions

- This feature is scoped only to the identifier representation used by Apple documentation content.
- Other Apple documentation content shape changes remain out of scope and should be handled as separate compatibility fixes with their own diagnostics.
- The public documentation content model remains stable for callers, adapters, cache files, and renderers.
- Existing source selection behavior remains stable; fallback sources are used only when earlier sources do not produce valid documentation content.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of fetch requests using valid Apple documentation content with structured identifier metadata succeed from the Apple source when cache and local content miss.
- **SC-002**: 100% of those successful Apple fetches report source attempts as cache, local, and Apple only, with no fallback source attempt.
- **SC-003**: 100% of existing fetch scenarios using string identifiers continue to pass without changing stored content format.
- **SC-004**: 100% of malformed structured identifiers without a URL produce a remote decode failure diagnostic instead of a successful fetch.
- **SC-005**: Existing invalid remote documentation fallback behavior remains unchanged across the fetch test suite.
