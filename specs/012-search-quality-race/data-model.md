# Data Model: Search Quality Race CI

## AuditCase

Represents one expected search behavior.

| Field | Required | Notes |
|-------|----------|-------|
| `id` | Yes | Stable case identifier used in samples, reports, and fingerprints |
| `framework` | Yes | Product/framework area such as SwiftUI, AppKit, UIKit, Foundation, Xcode, or App Store Connect |
| `queryShape` | Yes | `exact_symbol`, `composite`, `member_property`, `natural_language`, `fuzzy_typo`, or `invalid_no_result` |
| `query` | Yes | Full query string passed to each product target |
| `expectedOutcome` | Yes | Expected truth class, including canonical hit or invalid/no-result |
| `canonicalPaths` | No | Acceptable documentation paths for symbol/page hits |
| `requiredTerms` | No | Terms expected in title, path, snippet, or body evidence |
| `sourceFamily` | Yes | Expected source family for reporting and grouping |
| `ciEligible` | Yes | Only `true` cases may be sampled in CI |
| `runnerHints` | No | Product-specific hints, such as technology selection for a competitor |

Validation rules:
- `id`, `framework`, `queryShape`, `query`, `expectedOutcome`, `sourceFamily`, and `ciEligible` must be present.
- `canonicalPaths` is required for known canonical documentation outcomes.
- `requiredTerms` should be present for fuzzy and natural-language cases unless the expected outcome is invalid/no-result.
- CI sampling must exclude `ciEligible=false`.

## ProductTarget

Represents iDocs or one competitor evaluated in the same run.

| Field | Required | Notes |
|-------|----------|-------|
| `id` | Yes | Stable product ID used in summaries |
| `displayName` | Yes | Human-readable table label |
| `kind` | Yes | `idocs` or `competitor` |
| `packageSpec` | Competitors | Requested npm package spec |
| `resolvedVersion` | Competitors | Exact npm version resolved for the run |
| `binaryPath` | iDocs | Built iDocs binary path or identity |

Validation rules:
- Competitor targets must record `resolvedVersion`.
- iDocs target must record the commit and binary identity for the current repository version.

## AuditRun

Represents one scheduled or manual audit execution.

| Field | Required | Notes |
|-------|----------|-------|
| `runId` | Yes | Stable run identifier |
| `generatedAt` | Yes | ISO timestamp |
| `seed` | Yes | Random seed used by sampler |
| `sampleSize` | Yes | Requested sample size |
| `actualSampleSize` | Yes | Actual sampled eligible case count |
| `commitSha` | Yes | Commit under test |
| `idocsBinary` | Yes | Built binary identity/path |
| `targets` | Yes | ProductTarget list |
| `sample` | Yes | Ordered AuditCase IDs |
| `results` | Yes | ProductResult list |
| `diagnostics` | Yes | Run-level diagnostics, including remote-only marker |
| `artifacts` | Yes | Paths or names for JSON and Markdown artifacts |

Validation rules:
- Same `seed` and `sampleSize` over the same pool must produce the same ordered `sample`.
- `diagnostics` must include that local Xcode documentation comparison is excluded in CI.

## ProductResult

Represents one product's output for one audit case.

| Field | Required | Notes |
|-------|----------|-------|
| `caseId` | Yes | AuditCase ID |
| `targetId` | Yes | ProductTarget ID |
| `classification` | Yes | `symbol_hit`, `module_only`, `empty`, `wrong_framework`, `wrong_page`, `unsupported_misclassified`, or `network_error` |
| `verdict` | Yes | `pass`, `fail`, `infra`, or `not_applicable` |
| `topEvidence` | Yes | Short evidence shown in tables/issues |
| `rawEvidence` | Yes | Truncated or referenced raw output for artifact debugging |
| `diagnostics` | No | Product-specific diagnostics |
| `reproCommand` | iDocs failures | Local reproduction command |

Validation rules:
- Every sampled `caseId x targetId` pair must produce one ProductResult unless a runner-level infrastructure failure stops report generation.
- `empty` passes only for invalid/no-result expectations or explicitly allowed empty outcomes.
- `module_only` fails for symbol/member queries unless module-level success is explicitly allowed by the case.
- `network_error` is excluded from iDocs issue fingerprinting.

## FailureFingerprint

Represents the current actionable iDocs failure set.

| Field | Required | Notes |
|-------|----------|-------|
| `fingerprint` | Yes | Hash over sorted failure inputs |
| `caseIds` | Yes | Sorted failing case IDs |
| `expectedOutcomes` | Yes | Expected outcomes for failing cases |
| `classifications` | Yes | iDocs classifications for failing cases |

Validation rules:
- Ordering of runner execution must not change the fingerprint.
- Network and infrastructure results must not be included.

## IssueRecord

Represents issue collection outcome.

| Field | Required | Notes |
|-------|----------|-------|
| `action` | Yes | `none`, `created`, `commented`, or `dry_run` |
| `fingerprint` | Conditional | Present when actionable iDocs failures exist |
| `issueNumber` | Conditional | Present for live created/commented outcomes |
| `issueUrl` | Conditional | Present for live created/commented outcomes |
| `bodyPath` | Optional | Local body path for dry-run/debug |
| `labelsApplied` | Optional | Labels successfully applied |
| `labelsSkipped` | Optional | Labels unavailable or skipped |

Validation rules:
- No-failure runs must use `action=none`.
- Existing matching fingerprint must produce `commented`, not `created`.
- Missing preferred labels must not block `created`.
