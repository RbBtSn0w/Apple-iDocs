# Feature Specification: Agent Resolve Documentation Entry

**Feature Branch**: `013-agent-resolve-entry`
**Created**: Saturday, May 16, 2026
**Status**: Verified
**Input**: User description: "Make iDocs an AI-agent-facing Apple documentation evidence entry by adding a structured resolve capability, keeping fetch as the evidence surface, demoting search to exploration, and reframing the Search Quality Race as a layered evidence quality audit."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Resolve Structured Apple API Intents (Priority: P1)

As an AI agent using iDocs, I want to provide structured Apple API intent such as framework, symbol, type, and member, so I can receive a canonical documentation target with fetch-backed evidence instead of relying on natural-language search.

**Why this priority**: This is the P0 agent-facing product path. Agents can usually extract structured API intent from code and context, and that structured path must be more reliable than fuzzy search for evidence retrieval.

**Independent Test**: Can be tested by resolving each supported structured intent shape and verifying the response includes a canonical path, confidence, fetch verification status, evidence, candidates, and diagnostics.

**Acceptance Scenarios**:

1. **Given** an agent provides a framework and symbol for a documented Apple API, **When** it asks iDocs to resolve the intent, **Then** the response identifies the canonical documentation path and includes fetch-verified evidence.
2. **Given** an agent provides a framework, type, member, and member kind, **When** it asks iDocs to resolve the member intent, **Then** the response identifies the member documentation path or an explicitly ranked candidate set with diagnostics.
3. **Given** an agent provides an incomplete or invalid structured intent, **When** it asks iDocs to resolve the intent, **Then** iDocs returns a structured error and does not reinterpret the input as natural-language search.

---

### User Story 2 - Preserve Fetch as the Evidence Authority (Priority: P1)

As an AI agent or maintainer, I want every resolved answer to be validated through document fetching, so downstream claims are grounded in retrievable evidence rather than candidate ranking alone.

**Why this priority**: The product promise is evidence retrieval. A resolver result that cannot be fetched must not look authoritative to an agent.

**Independent Test**: Can be tested by resolving valid and invalid candidates and verifying that high-confidence answers are only emitted when the canonical or recovered candidate has fetch evidence.

**Acceptance Scenarios**:

1. **Given** a direct canonical path candidate can be fetched, **When** resolution completes, **Then** the answer is marked fetch verified and may be high confidence.
2. **Given** a direct canonical path candidate cannot be fetched, **When** resolution completes, **Then** the result is not high confidence and includes fetch diagnostics.
3. **Given** search fallback finds a possible candidate, **When** the candidate is not fetch verified, **Then** it remains diagnostic candidate evidence and does not become the authoritative answer.

---

### User Story 3 - Keep Search for Exploration (Priority: P2)

As a maintainer or agent, I want search to remain available for natural language, typos, and broad discovery, so exploratory lookup still works without making fuzzy search responsible for structured API correctness.

**Why this priority**: Search quality remains valuable, but it should not carry the primary agent evidence path when the caller can provide structured intent.

**Independent Test**: Can be tested by running natural-language, typo, and broad discovery cases and verifying they are reported as exploration quality instead of resolver correctness failures.

**Acceptance Scenarios**:

1. **Given** a broad natural-language query, **When** it is evaluated, **Then** it is classified as search exploration and judged on candidate quality.
2. **Given** a typo or broad discovery query fails to find an ideal result, **When** audit results are collected, **Then** the failure appears in the report but is not treated as a P0 resolver correctness failure by default.
3. **Given** a structured resolver case succeeds, **When** related fuzzy search cases are weak, **Then** the agent evidence path can still be considered healthy.

---

### User Story 4 - Reframe Quality Audits by Capability (Priority: P1)

As an iDocs maintainer, I want the existing search-quality benchmark to become a layered evidence quality audit, so resolver correctness, fetch evidence, and search exploration are assessed against their real product responsibilities.

**Why this priority**: The current all-search framing creates misleading blockers by treating natural-language search failures as if they invalidate the structured agent path.

**Independent Test**: Can be tested by running audit cases tagged by capability and verifying issue collection only creates P0 work for resolve or fetch golden-truth failures.

**Acceptance Scenarios**:

1. **Given** audit cases include structured API intents, **When** the audit runs, **Then** resolver correctness is evaluated separately from search exploration.
2. **Given** audit cases include canonical paths, **When** the audit runs, **Then** fetch evidence is evaluated separately from candidate discovery.
3. **Given** natural-language search cases fail, **When** issue collection runs, **Then** they are reported without automatically becoming P0 golden-truth issues.
4. **Given** a resolver or fetch golden-truth case fails, **When** issue collection runs, **Then** it is eligible for P0 issue creation or update.

### Edge Cases

- A caller provides `member` without a `type`; the intent must be rejected as invalid instead of guessed as a natural-language query.
- A caller omits `source-family`; Apple API documentation is used as the default source family.
- A direct candidate exists but fetch verification fails; the result must not be high confidence.
- Multiple fetch-verified candidates exist; the response must expose candidates and diagnostics so the caller can inspect ambiguity.
- Search fallback finds a candidate in the wrong framework or wrong type; the result must remain unresolved or low confidence unless the structured fields match.
- Help, App Store Connect, or other non-API pages remain supported through search and fetch, but are not required resolver targets in v1.
- Existing `search`, `fetch`, and `list` consumers must continue to receive compatible output when optional resolver-related fields are absent.
- Existing issue fingerprints from the prior all-search benchmark must not remain the sole closure standard after audit layering is introduced.
- Issue #11 must be treated as search exploration unless a structured resolver case for the same target fails with fetch-backed evidence expectations.
- Issue #12 must be split so structured API cases become resolver correctness requirements while help, Xcode, natural-language, and invalid/no-result cases remain in search or fetch exploration lanes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: iDocs MUST define structured document resolution as a P0 agent-facing capability.
- **FR-002**: iDocs MUST provide a resolver entry point that accepts structured fields for framework, symbol, type, member, member kind, source family, JSON output preference, and caller identity.
- **FR-003**: The resolver MUST treat framework plus symbol, framework plus type, and framework plus type plus member as valid structured intent shapes.
- **FR-004**: The resolver MUST reject invalid structured intents with a structured error and MUST NOT silently degrade them into natural-language search.
- **FR-005**: The resolver MUST default omitted source family to Apple API documentation.
- **FR-006**: Resolver responses MUST include canonical path, confidence, fetch verification status, evidence, candidates, resolver diagnostics, and fetch diagnostics.
- **FR-007**: A direct canonical path match MAY be high confidence only when fetch verification succeeds.
- **FR-008**: A member-level match MAY be high confidence only when the framework, type, member, and requested member kind are consistent with fetch-verified evidence.
- **FR-009**: No candidate may be returned as a high-confidence answer without fetch verification.
- **FR-010**: Search fallback MAY be used only as candidate recovery after structured path resolution fails or is ambiguous.
- **FR-011**: Search fallback MUST NOT override fetch evidence, and MUST NOT convert an unfetched candidate into an authoritative answer.
- **FR-012**: Search fallback results MAY receive medium or high confidence only when fetch verification succeeds and the structured intent fields match the fetched target.
- **FR-013**: Unverified or unfetchable results MUST be reported as unresolved or low-confidence diagnostic candidates.
- **FR-014**: Fetch MUST remain the evidence authority for a known canonical path.
- **FR-015**: Existing search, fetch, and list outputs MUST remain backward compatible; resolver-related additions may only add optional fields or new surfaces.
- **FR-016**: The shared documentation service boundary MUST expose the same resolve behavior used by the command-line resolver, mocks, and contract tests.
- **FR-017**: The quality audit case schema MUST support a capability field with at least resolve, search, and fetch values.
- **FR-018**: Resolve correctness audit cases MUST cover exact symbol and member API examples across SwiftUI, AppKit, UIKit, and Foundation.
- **FR-019**: Search exploration audit cases MUST cover natural language, typo, and broad discovery behavior and judge candidate quality rather than resolver correctness.
- **FR-020**: Fetch evidence audit cases MUST verify content, source family, and diagnostics for known canonical paths.
- **FR-021**: Issue collection MUST automatically create or update P0 issues only for resolve or fetch golden-truth failures.
- **FR-022**: Natural-language search failures MUST appear in audit reports but MUST NOT automatically enter P0 failure fingerprints by default.
- **FR-023**: Existing issues that describe all-search failures MUST be reclassified or split according to the new resolve, search, and fetch capability boundaries.
- **FR-024**: Project guidance MUST explicitly state that structured resolution is the P0 agent-facing path and that iDocs remains CLI-first.
- **FR-025**: Confidence MUST use these caller-facing states: high for fetch-verified exact structured matches, medium for fetch-verified fallback candidates that match required structured fields, low for plausible but incomplete or mismatched candidates, and unresolved when no fetch-verified candidate satisfies the structured intent.
- **FR-026**: Evidence MUST include enough fetch-backed information for an agent to justify the resolved target, including source family, source identifier, title or summary when available, and diagnostic attempts that explain how the evidence was obtained.
- **FR-027**: Resolver diagnostics MUST describe intent validation, direct path attempts, fallback use, ambiguity, and field-match decisions separately from fetch diagnostics.
- **FR-028**: Fetch diagnostics MUST describe source attempts and fetch failures for candidate verification without being merged into resolver scoring diagnostics.
- **FR-029**: Issue #11 MUST be reclassified as search exploration unless a matching structured resolve case fails independently.
- **FR-030**: Issue #12 MUST be split into resolver correctness cases for structured API failures and search or fetch exploration cases for help, Xcode, natural-language, and invalid/no-result failures.

### Key Entities

- **Resolve Intent**: Structured caller input containing framework, symbol or type, optional member metadata, source family, output preference, and caller identity.
- **Resolve Result**: The resolver outcome containing canonical path, confidence, fetch verification status, evidence, candidates, and diagnostics.
- **Confidence**: The caller-facing certainty state for a resolved target. High requires a fetch-verified exact structured match; medium requires a fetch-verified fallback match; low indicates plausible but incomplete or mismatched candidates; unresolved means no candidate satisfies the structured intent with fetch evidence.
- **Evidence**: Fetch-backed content or metadata that lets an agent substantiate an Apple documentation claim, including source family, source identifier, title or summary when available, and diagnostic attempts.
- **Candidate**: A possible documentation target produced by direct resolution or fallback discovery before final confidence is assigned.
- **Resolve Diagnostics**: Resolver observations that explain invalid input, path attempts, fallback behavior, ambiguity, and structured-field matching decisions.
- **Fetch Diagnostics**: Fetch observations that explain source attempts, source family, status, failure reason, and status codes when available.
- **Audit Case**: A benchmark case tagged by capability and expectation, used to evaluate resolve correctness, search exploration, or fetch evidence.
- **Failure Fingerprint**: A stable grouping for actionable resolve or fetch golden-truth failures that may require issue creation or update.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of valid structured resolver smoke cases for exact symbol, member property, and member method intents return machine-readable output containing canonical path, confidence, fetch verification status, evidence, candidates, and diagnostics.
- **SC-002**: 0 high-confidence resolver results are emitted without successful fetch verification.
- **SC-003**: 100% of invalid structured intents return a structured error without running natural-language search fallback.
- **SC-004**: 100% of existing search, fetch, and list compatibility tests continue to pass without requiring consumers to read new resolver fields.
- **SC-005**: 100% of audit cases are classified under exactly one primary capability: resolve, search, or fetch.
- **SC-006**: 100% of resolve correctness audit cases verify structured intent matching and fetch-backed evidence before passing.
- **SC-007**: 100% of fetch evidence audit cases verify source family, content availability, and diagnostics for the requested canonical path.
- **SC-008**: 100% of search exploration failures are reported without automatically creating P0 issue fingerprints by default.
- **SC-009**: 100% of P0 issue automation is limited to resolve and fetch golden-truth failures.
- **SC-010**: Maintainers can determine whether a failure belongs to resolve correctness, fetch evidence, or search exploration from the audit report in under 2 minutes.

## Assumptions

- iDocs remains CLI-first and does not introduce MCP as the main product path for this feature.
- AI agents are responsible for extracting structured intent from code or surrounding context.
- Resolver v1 focuses on Apple API documentation; Help, App Store Connect, and other page families remain available through search and fetch unless a later feature expands structured resolution.
- Search remains supported and can continue improving, but it is an exploration surface rather than the first responsibility for agent evidence retrieval.
- Existing Search Quality Race work is not discarded; it is reframed into a layered evidence quality audit with clearer capability ownership.

## Source Coverage Traceability

- **P0 agent-facing resolver**: Covered by User Story 1, FR-001 through FR-006, FR-024, SC-001, and SC-003.
- **Fetch-backed confidence**: Covered by User Story 2, FR-007 through FR-014, SC-002, SC-006, and SC-007.
- **Search demotion to exploration**: Covered by User Story 3, FR-010 through FR-012, FR-019, FR-022, and SC-008.
- **Layered benchmark and issue handling**: Covered by User Story 4, FR-017 through FR-023, SC-005, SC-009, and SC-010.
- **Compatibility boundary**: Covered by FR-015, FR-016, SC-004, and Assumptions.
