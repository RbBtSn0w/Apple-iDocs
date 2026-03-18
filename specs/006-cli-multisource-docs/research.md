# Research: CLI Multi-Source Retrieval and Local Xcode Completion

## 1. Local Search Completion Strategy

- **Decision**: Implement practical local search by scanning available local documentation metadata/content files via existing filesystem abstraction; keep Spotlight as optional enhancer rather than hard dependency.
- **Rationale**: Current local search path is placeholder-only. A deterministic file-based local search works in tests and real environments without requiring fragile platform-only query integration first.
- **Alternatives considered**:
  - Full LMDB index integration now: stronger performance, but high implementation risk/scope for this feature.
  - Keep placeholder and rely on remote: violates offline-first principle and feature goals.

## 2. Dual Remote Fallback Policy

- **Decision**: Use ordered remote policy `apple -> sosumi` for `search` and `fetch` after cache/local layers.
- **Rationale**: Preserves official-source preference while improving resilience against endpoint failures and no-result conditions.
- **Alternatives considered**:
  - sosumi-first: better consistency with rendered content but weakens official-source priority.
  - explicit manual source only: predictable but worse UX and higher user burden.

## 3. Source Hit Observability

- **Decision**: Propagate source metadata through core result models and adapter output, then render source in CLI output.
- **Rationale**: Source visibility is needed for debugging, acceptance tests, and gate checks.
- **Alternatives considered**:
  - log-only source tracing: hard to assert in unit tests and scripts.
  - hidden internal metrics only: insufficient for contract-level observability.

## 4. Error Contract Stability Across Layers

- **Decision**: Keep existing CLI error categories and map new fallback/source failures into existing taxonomy.
- **Rationale**: Prevents breaking scripts and preserves user expectations.
- **Alternatives considered**:
  - introduce brand-new error categories per source: richer but disruptive for users.

## 5. Gate Coverage Extension

- **Decision**: Extend existing architecture gate with capability/contract drift checks for `search` and `fetch` source-chain behavior and docs alignment.
- **Rationale**: Current checks protect layering boundaries but not capability regression.
- **Alternatives considered**:
  - rely only on tests: may miss docs/contract drift.
  - docs-only review checklist: not enforceable in CI.
