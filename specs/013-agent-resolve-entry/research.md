# Research: Agent Resolve Documentation Entry

## Decision: Add a dedicated structured resolver instead of expanding fuzzy search

**Decision**: Implement a resolver path that accepts structured API intent and synthesizes canonical documentation paths before using search fallback.

**Rationale**: Agents usually have framework/type/member context from source code. Treating that as natural language loses precision and pushes structured correctness onto search ranking.

**Alternatives considered**:
- Keep improving `search` only. Rejected because natural-language exploration and exact API evidence retrieval have different correctness criteria.
- Add NLP/embedding intent extraction inside iDocs. Rejected for v1 because the agent can extract structured intent and the product boundary should stay CLI-first and deterministic.

## Decision: Fetch verification gates confidence

**Decision**: A candidate can be high confidence only when fetch verification succeeds. Search fallback candidates without fetch evidence remain low confidence or unresolved diagnostics.

**Rationale**: The product is an evidence entry, not a ranker. Agents need retrievable documentation evidence before making API claims.

**Alternatives considered**:
- Trust direct path synthesis without fetch. Rejected because stale or malformed paths would appear authoritative.
- Trust search top hit. Rejected because search can return module-level or wrong-framework pages.

## Decision: Resolve diagnostics and fetch diagnostics stay separate

**Decision**: Resolver diagnostics describe intent validation, path attempts, fallback usage, ambiguity, and field matching. Fetch diagnostics describe source attempts and failures.

**Rationale**: Maintainers and agents need to distinguish "we could not identify the right target" from "we identified a target but could not fetch evidence."

**Alternatives considered**:
- Use one generic diagnostics array. Rejected because it obscures whether the failure belongs to resolution or evidence retrieval.

## Decision: Keep non-API pages out of resolver v1

**Decision**: Help, App Store Connect, Xcode help, and invalid/no-result cases stay in search/fetch exploration unless a later feature expands structured resolution.

**Rationale**: The P0 agent path is Apple API documentation. Expanding v1 to heterogeneous page families would dilute the resolver contract and increase ambiguity.

**Alternatives considered**:
- Support all Apple page families immediately. Rejected because source-family semantics and canonical path rules differ enough to need separate design.

## Decision: Reframe Search Quality Race by capability

**Decision**: Add a primary capability dimension to audit cases and issue collection: `resolve`, `fetch`, or `search`.

**Rationale**: Natural-language search failures should remain visible without blocking the structured agent evidence path. Resolve/fetch golden-truth failures are the P0 issue surface.

**Alternatives considered**:
- Keep one all-search benchmark and reclassify findings manually. Rejected because old fingerprints would keep conflating exploration quality with resolver correctness.
