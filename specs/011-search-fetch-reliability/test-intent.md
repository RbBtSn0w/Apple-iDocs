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

## Addendum: Module Hint Short-Circuit

### Risk

Composite API-symbol queries such as `SwiftUI NavigationSplitView` can be reported as successful while returning only a framework/module page, causing agents to cite the wrong evidence.

### Why Automation

The regression is deterministic local search control flow and JSON contract behavior. Manual CLI checks would miss whether provider/index search was skipped and whether the returned result is marked as a module fallback.

### Why Existing Tests Insufficient

Existing 011 tests cover mixed source classification and fallback provenance, but one older local-docs test explicitly encoded "composite query returns module and skips provider search" as desired behavior.

### Chosen Layer

Unit-style Swift Testing in `XcodeLocalDocsMockTests` for local search sequencing plus CLI JSON/text tests for `match_scope`. This is the smallest layer that covers both root cause and public output.

### Fragility Analysis

Tests use mock file systems, mock search providers, and synthetic `DeveloperDocumentation.index` byte payloads. They avoid live Apple services and do not depend on private Xcode database decoding beyond direct path-string extraction already implemented by the production code.

### If Omitted

The CLI can keep short-circuiting symbol-oriented searches at module hints, making `idocs search -> idocs fetch` look usable while failing to find the actual API page.
