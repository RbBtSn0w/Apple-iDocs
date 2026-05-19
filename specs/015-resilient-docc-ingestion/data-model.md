# Data Model: Resilient DocC Ingestion

## JSONValue

| Field | Required | Description |
|-------|----------|-------------|
| case | Yes | One of string, number, bool, object, array, or null |
| object entries | For object | String-keyed child values |
| array entries | For array | Ordered child values |

### Validation Rules

- Used only at the Apple remote ingestion boundary.
- Must remain Codable, Sendable, and Equatable.
- Must not be exposed through public fetch output or cache output.

## AppleDocCIngestionResult

| Field | Required | Description |
|-------|----------|-------------|
| content | Yes | Stable normalized `DocCContent` |
| diagnostics | Yes | Path-aware partial diagnostics collected while normalizing |

### Validation Rules

- A result is successful only when required core evidence exists.
- Diagnostics may be empty for fully stable payloads.
- Diagnostics are surfaced through Apple source attempt metadata.

## AppleDocCDiagnostic

| Field | Required | Description |
|-------|----------|-------------|
| severity | Yes | Partial or failure |
| path | Yes | JSON path of the skipped or missing node |
| reason | Yes | Machine-readable reason |
| detail | No | Human-readable detail for maintainers |

### Validation Rules

- Partial diagnostics do not prevent Apple source success.
- Failure diagnostics prevent Apple source success and allow fallback behavior.

## Stable DocCContent

| Field | Required | Description |
|-------|----------|-------------|
| identifier | Yes | Stable string identifier |
| metadata.title | Yes | Stable title used by renderer |
| abstract | No | Known inline content normalized from Apple payload |
| primaryContentSections | No | Known renderable content sections |
| topicSections | No | Known topic identifiers |
| relationshipsSections | No | Known relationship identifiers |
| seeAlsoSections | No | Known see-also identifiers |
| references | No | Known reference entries |

### Validation Rules

- Encoded output remains stable and does not include raw `JSONValue`.
- Unknown non-critical nodes are skipped rather than stored in public model.
