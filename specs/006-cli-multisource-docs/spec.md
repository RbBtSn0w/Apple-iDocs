# Feature Specification: iDocs CLI Capability Unification and Multi-Source Retrieval

**Feature Branch**: `006-cli-multisource-docs`  
**Created**: 2026-03-18  
**Status**: completed  
**Input**: User description: "iDocs has migrated from MCP interaction to CLI. Keep capability goals, complete local Xcode doc access, and add sosumi.ai as an additional remote source under a deterministic retrieval chain."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Unified CLI Contract (Priority: P1)

As a CLI user, I want stable `idocs` command behavior for search and fetch so that I can reliably retrieve documentation without learning historical MCP tool boundaries.

**Why this priority**: Command stability is the primary user-facing value and blocks safe adoption by scripts and teams.

**Independent Test**: Run CLI help and command invocations to verify command shape, outputs, and error categories are deterministic and documented.

**Acceptance Scenarios**:

1. **Given** a clean build, **When** I run `idocs --help` and subcommand help, **Then** documented commands and options match the implemented CLI surface.
2. **Given** normal input, **When** I run `idocs search` or `idocs fetch`, **Then** the CLI returns successful output with consistent formatting and exit code `0`.
3. **Given** invalid or failed requests, **When** an error occurs, **Then** the CLI returns standardized error categories and a non-zero exit code.

---

### User Story 2 - Complete Local Xcode Retrieval (Priority: P1)

As a developer with downloaded Xcode documentation, I want local documentation to be used before remote services so that I can work with low latency and offline resilience.

**Why this priority**: Local-first behavior is a core project differentiator and directly improves reliability and speed.

**Independent Test**: With local docs present, run search/fetch in online and offline conditions and verify local hits are returned without remote dependency.

**Acceptance Scenarios**:

1. **Given** local Xcode docs are present, **When** I run `idocs search "SwiftUI"`, **Then** matching local results can be returned without requiring remote sources.
2. **Given** local docs and no network, **When** I run `idocs fetch <existing-local-id>`, **Then** the CLI still returns content successfully.
3. **Given** local docs are missing or unreadable, **When** I run search/fetch, **Then** the CLI falls through to remote retrieval instead of terminating unexpectedly.

---

### User Story 3 - Dual Remote Fallback Resilience (Priority: P1)

As a developer, I want deterministic remote fallback from Apple source to sosumi source so that retrieval still succeeds when one upstream source fails or returns no results.

**Why this priority**: Upstream endpoint volatility is a known risk; deterministic fallback preserves availability.

**Independent Test**: Simulate Apple remote failure/no-result and verify automatic fallback to sosumi for search/fetch.

**Acceptance Scenarios**:

1. **Given** Apple remote source is healthy, **When** I run search/fetch with a cache/local miss, **Then** Apple remote is attempted first.
2. **Given** Apple remote fails or returns no results, **When** I run search/fetch, **Then** the system automatically retries through sosumi remote before returning failure.
3. **Given** both remote sources fail, **When** I run search/fetch, **Then** the CLI reports a standardized terminal error category.

---

### User Story 4 - Source Visibility and Anti-Regression Gates (Priority: P2)

As a maintainer, I want source-hit visibility and automated gates so that future refactors cannot silently regress capability coverage or contract consistency.

**Why this priority**: Prevents recurring drift between implementation, tests, and docs.

**Independent Test**: Run local gate scripts and CI checks to confirm capability matrix, source-hit reporting, and contract consistency checks pass.

**Acceptance Scenarios**:

1. **Given** any successful result, **When** search/fetch completes, **Then** the result path can identify which layer served it (`cache`, `local`, `apple`, or `sosumi`).
2. **Given** a documentation update, **When** checks run, **Then** they fail if command contract and docs are inconsistent.
3. **Given** a capability removal, **When** gates run, **Then** capability regression is detected before merge.

### Edge Cases

- What happens when local Xcode directory exists but index/content is partially corrupted?
- How does the system behave when Apple remote is reachable but returns structurally invalid payloads?
- How does the system handle no-hit queries across all layers without masking with incorrect success output?
- What happens when multiple layers return data with conflicting titles/metadata for the same identifier?
- How is behavior defined when source-hit reporting is unavailable due to internal mapping errors?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a stable CLI entrypoint using `idocs` with explicit, documented command contracts for search and fetch.
- **FR-002**: System MUST preserve capability equivalence goals in CLI form; command regrouping is allowed, capability loss is not.
- **FR-003**: System MUST execute retrieval using a deterministic layered policy where cache and local layers are attempted before remote layers.
- **FR-004**: System MUST complete local Xcode search behavior so local search is a functional retrieval path rather than a placeholder path.
- **FR-005**: System MUST support local Xcode content fetch as part of the normal fetch pipeline.
- **FR-006**: System MUST support two remote sources for search and fetch: Apple official source and sosumi source.
- **FR-007**: System MUST use Apple remote as the default first remote source and MUST fall back to sosumi when Apple fails or yields no results.
- **FR-008**: System MUST expose source-hit information for successful retrievals with source values from: `cache`, `local`, `apple`, `sosumi`.
- **FR-009**: System MUST keep error categories and non-zero exit semantics stable across all source paths.
- **FR-010**: System MUST ensure README, spec/contracts, and CLI help/output contracts are synchronized for affected commands.
- **FR-011**: System MUST provide automated checks that detect capability regression and contract drift prior to merge.
- **FR-012**: System MUST remain CLI-only for this feature; MCP runtime and transport behavior are excluded.

### Key Entities *(include if feature involves data)*

- **SourcePolicy**: Defines ordered retrieval precedence for each operation (`search`, `fetch`) across layers.
- **SourceHit**: Records which layer produced the final result (`cache`, `local`, `apple`, `sosumi`) for observability and testing.
- **CapabilityMatrix**: Explicit mapping of required user capabilities to CLI-accessible command paths.
- **CLIErrorContract**: Stable category-oriented error surface and exit-code semantics independent of source path.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of required capabilities in the declared capability matrix have at least one CLI-reachable command path.
- **SC-002**: In controlled tests with local docs available, at least 95% of targeted local search/fetch cases succeed without remote dependency.
- **SC-003**: In controlled tests where Apple remote fails or returns no results, fallback to sosumi is attempted and completes successfully in at least 95% of applicable cases.
- **SC-004**: Source-hit values are present and valid for 100% of successful search/fetch responses in automated tests.
- **SC-005**: Contract consistency checks fail on any mismatch between implemented CLI behavior and documented command contract.
- **SC-006**: Architecture and capability gates pass in local and CI runs for this feature branch.
