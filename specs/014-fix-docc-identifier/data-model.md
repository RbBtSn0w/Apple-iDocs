# Data Model: Robust DocC Identifier Fetch

## DocCContent

| Field | Required | Description |
|-------|----------|-------------|
| `identifier` | Yes | Canonical documentation identifier exposed to callers as a string |
| `metadata` | Yes | Existing documentation metadata |
| `abstract` | No | Existing inline abstract content |
| `primaryContentSections` | No | Existing primary content sections |
| `topicSections` | No | Existing topic sections |
| `relationshipsSections` | No | Existing relationship sections |
| `seeAlsoSections` | No | Existing see-also sections |
| `references` | No | Existing references map |

### Validation Rules

- A string identifier is valid and remains unchanged.
- A structured identifier is valid only when it contains a non-missing URL string.
- A valid structured identifier normalizes to its URL string.
- A structured identifier without URL is invalid and must fail decoding.
- Encoding always emits the normalized string identifier.

## DocCIdentifierMetadata

| Field | Required | Description |
|-------|----------|-------------|
| `url` | Yes | Canonical DocC identifier URL used as the public `DocCContent.identifier` value |
| `interfaceLanguage` | No | Upstream metadata describing language variant; accepted but not exposed as new public API |

### Validation Rules

- `url` must be present for the object shape to be accepted.
- `interfaceLanguage` does not affect source selection, public content shape, or cache output.

## Fetch Source Attempt

| Field | Required | Description |
|-------|----------|-------------|
| `source` | Yes | Cache, local, Apple, or fallback source attempted by fetch |
| `status` | Yes | Success, miss, or error state for the attempt |
| `reason` | No | Machine-readable diagnostic such as `remote_decode_failed` |

### State Rules

- Valid Apple content with structured identifier ends the source chain at Apple.
- Invalid Apple content records the existing remote decode failure diagnostic and allows fallback behavior to continue.
