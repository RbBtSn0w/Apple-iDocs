# Test Intent: Search and Fetch Reliability for Mixed Apple Documentation Sources

## Risk

Agents depend on `idocs search -> idocs fetch` for Apple evidence. Mixed Apple page families currently produce misleading fetch failures, hidden fallback provenance, and unclear remote-only degradation.

## Why Automation

The failures are deterministic data classification, error mapping, and CLI serialization risks. Manual checks would miss regressions in JSON fields, adapter mappings, and ordered source attempts.

## Why Existing Tests Insufficient

Existing tests cover basic search/fetch fallback and search diagnostics, but they do not assert source kind, fetch support, query-attempt provenance, Help-page fetch behavior, unsupported-source classification, or fetch-attempt diagnostics.

## Chosen Layer

Unit and integration-style Swift Testing at the existing kit, adapter, and CLI layers. This is the smallest effective layer because behavior is pure model mapping plus mocked network/file-system flows.

## Fragility Analysis

Tests use mocked network sessions, mocked file systems, and stable JSON/HTML fixtures. They avoid live Apple services, timing assertions, private call counts, or UI hierarchy.

## If Omitted

The CLI can regress to returning real Apple Help/news/video paths as fetchable search results or misleading `NOT_FOUND` fetch errors, breaking agent evidence collection again.
