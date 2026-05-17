# Data Model: Agent Resolve Documentation Entry

## ResolveIntent

| Field | Required | Description |
|-------|----------|-------------|
| `framework` | Conditional | Apple framework/module, required for all valid v1 intents |
| `symbol` | Conditional | Exact symbol name for `framework + symbol` intents |
| `type` | Conditional | Type name for `framework + type` and member intents |
| `member` | Optional | Member name for member-level intents; valid only with `type` |
| `memberKind` | Optional | Member category such as property or method |
| `sourceFamily` | Optional | Defaults to `documentation` |
| `caller` | Optional | Opaque agent/workflow caller identity |

### Validation Rules

- `framework + symbol` is valid.
- `framework + type` is valid.
- `framework + type + member` is valid.
- `member` without `type` is invalid.
- Missing `framework` is invalid for v1.
- Empty or whitespace-only structured fields are treated as absent.
- `sourceFamily` defaults to `documentation`.

## ResolveResult

| Field | Required | Description |
|-------|----------|-------------|
| `canonicalPath` | No | Final canonical documentation path when resolved |
| `confidence` | Yes | `high`, `medium`, `low`, or `unresolved` |
| `verifiedByFetch` | Yes | Whether the authoritative candidate was fetch verified |
| `evidence` | No | Fetch-backed evidence for the resolved target |
| `candidates` | Yes | Candidate list from direct path synthesis and optional fallback |
| `resolveDiagnostics` | Yes | Resolver diagnostics |
| `fetchDiagnostics` | No | Fetch diagnostics from candidate verification |

### Confidence Rules

- `high`: Direct or exact structured candidate fetches successfully and all required intent fields match.
- `medium`: Search fallback candidate fetches successfully and all required structured fields match.
- `low`: Candidate is plausible but not fetch verified or has incomplete field matching.
- `unresolved`: No fetch-verified candidate satisfies the structured intent.

## ResolveEvidence

| Field | Required | Description |
|-------|----------|-------------|
| `sourceFamily` | Yes | Evidence family, default `documentation` |
| `source` | Yes | Fetch source such as cache, local, apple, or sosumi |
| `path` | Yes | Evidence path |
| `title` | No | Title extracted from fetched content |
| `summary` | No | Short content excerpt or summary suitable for agent display |

## ResolveCandidate

| Field | Required | Description |
|-------|----------|-------------|
| `path` | Yes | Candidate documentation path |
| `title` | No | Candidate title when known |
| `source` | Yes | `direct` or `search_fallback` |
| `matchQuality` | Yes | Field match summary such as exact, partial, mismatch |
| `verifiedByFetch` | Yes | Whether this candidate fetched successfully |
| `confidence` | Yes | Candidate-level confidence |

## ResolveDiagnostic

| Field | Required | Description |
|-------|----------|-------------|
| `stage` | Yes | Validation, direct path, fallback, scoring, or ambiguity stage |
| `status` | Yes | `hit`, `miss`, `skipped`, `error`, or `ambiguous` |
| `reason` | No | Machine-readable reason |
| `pathAttempt` | No | Candidate path tried during this stage |
| `hint` | No | Human-readable guidance for caller/maintainer |

## AuditCase Capability Layer

| Field | Required | Description |
|-------|----------|-------------|
| `capability` | Yes | `resolve`, `fetch`, or `search` |
| `structuredIntent` | For resolve | Framework/type/member/symbol expectation |
| `canonicalPath` | For fetch | Known path to fetch |
| `query` | For search | Natural-language, typo, or broad discovery query |
| `p0IssueEligible` | Yes | True only for resolve/fetch golden-truth expectations by default |

### Validation Rules

- Every audit case has exactly one primary capability.
- Resolve cases must include structured intent.
- Fetch cases must include canonical path.
- Search cases must not be P0 issue eligible by default.
- Issue #11 maps to search exploration unless a matching structured resolver failure is added.
- Issue #12 maps structured API failures to resolve and leaves help/Xcode/natural-language/invalid-no-result failures in search or fetch lanes.
