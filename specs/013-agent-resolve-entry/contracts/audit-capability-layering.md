# Contract: Evidence Quality Audit Capability Layering

## Audit Case Schema Additions

Each audit case includes:

```json
{
  "id": "resolve-swiftui-navigation-split-view",
  "capability": "resolve",
  "p0IssueEligible": true,
  "structuredIntent": {
    "framework": "SwiftUI",
    "symbol": "NavigationSplitView",
    "sourceFamily": "documentation"
  }
}
```

## Capability Rules

- `resolve`: structured intent correctness; must verify structured fields and fetch-backed evidence.
- `fetch`: canonical path evidence correctness; must verify content/source/diagnostics for a known path.
- `search`: exploration/candidate quality; visible in report but not P0 issue eligible by default.

## Issue Collection Rules

- P0 issue fingerprints include only iDocs failures where `capability` is `resolve` or `fetch` and `p0IssueEligible` is true.
- Search exploration failures remain in report output and summary tables.
- Issue #11 is represented as `search` unless a matching structured resolve case is added.
- Issue #12 structured API cases are represented as `resolve`; help/Xcode/natural-language/invalid-no-result cases remain `search` or `fetch`.

## Report Requirements

- Product and failure summaries group results by capability.
- Maintainers can identify resolve correctness, fetch evidence, and search exploration failures independently.
- Old all-search fingerprints are not the sole closure standard after this migration.
