# Data Model: Search and Fetch Reliability for Mixed Apple Documentation Sources

## SourceKind

Represents the Apple page family for a search result or fetch path.

Fields:

- `rawValue`: Stable string value: `documentation`, `help`, `video`, `news`, `marketing`, `unknown`

Validation:

- `/documentation/...` maps to `documentation`
- `/help/...` maps to `help`
- `/videos/...` maps to `video`
- `/news` and `/news/...` map to `news`
- `/app-store-connect/...` and other broad Apple product pages map to `marketing` unless more specific support exists
- Empty or unrecognized paths map to `unknown`

## FetchCapability

Represents whether a search result is expected to work with `idocs fetch`.

Fields:

- `supported`: Boolean
- `reason`: Optional stable reason string when unsupported or conditional

Validation:

- Documentation paths are supported.
- App Store Connect Help paths are supported by the Help fetch adapter.
- Video, news, and unsupported marketing paths are not supported and must include a reason.

## QueryAttempt

Represents a user query or derived query used during search.

Fields:

- `query`: The exact attempted query string
- `kind`: Stable value such as `original` or `keyword_fallback`

Validation:

- Every result must record the query attempt that produced it.
- The original query must always be represented in search instrumentation.

## Search Result

Extends existing search result metadata.

Fields:

- Existing: `title`, `abstract`, `path`, `kind`, `source`, `relevance`
- New: `sourceKind`, `fetchSupported`, `fetchSupportReason`, `queryAttempt`

Validation:

- `sourceKind` must be derived from `path`.
- `fetchSupported` must match `sourceKind` and known path support.
- `queryAttempt` must be present for remote/fallback results; cache results preserve the cached attempt when available or default to original.

## Search Diagnostic Stage

Extends existing stage timing with capability and query information.

Fields:

- Existing: `name`, `status`, `durationMs`, `resultCount`, `reason`, `hint`
- New: optional `queryAttempt`

Validation:

- Missing local Xcode documentation uses a machine-readable reason such as `local_docs_unavailable`.
- Remote-only continuation remains a non-fatal miss/error stage followed by remote stages.

## Fetch Source Attempt

Represents one ordered fetch attempt.

Fields:

- `source`: `cache`, `local`, `apple`, `help`, `sosumi`, or `unsupported`
- `status`: `hit`, `miss`, `error`, or `unsupported`
- `reason`: Optional stable reason such as `remote_decode_failed`, `http_500`, `unsupported_source_type`, `not_found`
- `contentType`: Optional sanitized content type
- `statusCode`: Optional HTTP status code
- `hint`: Optional user-facing/actionable hint

Validation:

- Attempts are ordered by the actual fetch sequence.
- Successful fetches include all prior failed attempts and the final hit.
- Aggregate failures include every attempted source and final category.

## Fetch Result

Extends fetched documentation output.

Fields:

- Existing: `markdown`, `source`
- New: `sourceAttempts`

Validation:

- `source` remains the final successful source for backward compatibility.
- `sourceAttempts` records provenance for successful and failed fallback flows.

## Unsupported Source Error

Represents a real Apple page family that the CLI intentionally does not fetch.

Fields:

- `id`: Requested path
- `sourceKind`: Page family
- `reason`: `unsupported_source_type`

Validation:

- Unsupported videos, news, and unsupported marketing paths must not map to `NOT_FOUND`.
- CLI output should classify these as a configuration/unsupported-source category rather than documentation absence.
