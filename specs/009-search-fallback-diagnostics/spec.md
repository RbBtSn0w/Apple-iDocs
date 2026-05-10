# Feature Specification: search-fallback-diagnostics

**Feature Branch**: `009-search-fallback-diagnostics`  
**Created**: 2026-05-09  
**Status**: In Review
**Input**: User description: "Fix Apple-iDocs search quality and fallback diagnostics failure when Xcode DocumentationCache is not found."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Graceful Degradation on Network Failure (Priority: P1)

As an automated agent running `idocs search` without local Xcode documentation and without network permissions, I need to receive clear, structured diagnostics indicating a network/permission failure rather than a "no results" error, so I know I should request network access or retry rather than concluding the API doesn't exist.

**Why this priority**: Preventing false negatives is critical for agent workflows. If the agent thinks an API doesn't exist because of a sandboxing issue, it will make incorrect claims.

**Independent Test**: Can be fully tested by running `idocs search` in an environment where network access is blocked and local cache is missing.

**Acceptance Scenarios**:

1. **Given** local documentation is missing and network access is blocked (e.g., sandbox), **When** running `idocs search "SwiftUI inspector"`, **Then** the output clearly indicates a network/permission failure rather than a simple "not found" message.
2. **Given** local documentation is missing and network access is blocked, **When** running `idocs search`, **Then** the output includes actionable diagnostics for retrying.

---

### User Story 2 - Accurate Remote Fallback Search (Priority: P1)

As an automated agent or user running `idocs search` without local Xcode documentation but with network access, I need the remote fallback search to successfully find official Apple documentation for exact API or HIG terms.

**Why this priority**: When local docs are missing, falling back to remote search should provide equivalent or near-equivalent precision to maintain the utility of Apple-iDocs.

**Independent Test**: Can be fully tested by querying known Apple terms (e.g., `NavigationSplitView`) in an environment with network access but no local cache.

**Acceptance Scenarios**:

1. **Given** local documentation is missing and network access is available, **When** searching for "NavigationSplitView", **Then** the fallback mechanism returns relevant official Apple documentation links.
2. **Given** local documentation is missing and network access is available, **When** searching for "inspectorColumnWidth", **Then** the fallback mechanism returns relevant official Apple documentation links.

---

### User Story 3 - Distinguishing True Misses (Priority: P2)

As an automated agent or user, I need the search system to reliably tell me when a queried concept genuinely does not exist in Apple documentation, rather than returning generic network errors or false positives.

**Why this priority**: Accurate "not found" responses prevent wild goose chases and inform the agent to try alternative strategies or look for third-party libraries.

**Independent Test**: Can be fully tested by querying a completely fictitious API term.

**Acceptance Scenarios**:

1. **Given** network access is available and local documentation is missing, **When** searching for a non-existent API term, **Then** the output explicitly states that no matching documentation was found, distinct from any network error messages.

### Edge Cases

- What happens when a search request times out instead of returning a hard "operation not permitted" error?
- How does system handle malformed API queries or special characters during a fallback search?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST detect when local Xcode DocumentationCache is unavailable.
- **FR-002**: When local cache is unavailable, the system MUST attempt a remote lookup.
- **FR-003**: The system MUST differentiate between a remote lookup failing due to network/permission issues and a successful lookup that yields zero results.
- **FR-004**: On network/permission failure, the system MUST output actionable diagnostic messages indicating the nature of the failure (e.g., permission denied) to inform retry strategies.
- **FR-005**: The system MUST route exact API or HIG terminology queries to relevant official Apple Developer documentation pages during a remote fallback.
- **FR-006**: The system MUST maintain its CLI-first interface without requiring graphical interaction or opening a browser window directly unless explicitly requested.

### Key Entities

- **Search Query**: The raw input provided to the `idocs search` command.
- **Diagnostic Result**: Structured output detailing the reason for a search failure (e.g., Missing Local Cache, Network Blocked, API Not Found).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `idocs search` successfully returns correct documentation links for "NavigationSplitView", "inspectorColumnWidth", and "Split views" in 100% of attempts when local cache is missing but network is available.
- **SC-002**: `idocs search` explicitly outputs network/permission diagnostics in 100% of attempts when both local cache and network access are unavailable.
- **SC-003**: Agents parsing the CLI output can accurately distinguish a true "No Results" state from a "Network Error" state in 100% of test scenarios.
