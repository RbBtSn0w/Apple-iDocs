# Contract: Random Search Audit Record

## Top-Level Artifact

`random-search-audit.json` must include:

| Field | Required | Description |
|-------|----------|-------------|
| `schemaVersion` | Yes | Version of this artifact contract |
| `runId` | Yes | Unique audit run ID |
| `generatedAt` | Yes | ISO timestamp |
| `seed` | Yes | Sampler seed |
| `sampleSize` | Yes | Requested sample size |
| `actualSampleSize` | Yes | Number of sampled cases |
| `commitSha` | Yes | Commit under test |
| `idocsBinary` | Yes | Built iDocs binary path or identity |
| `remoteOnly` | Yes | Boolean marker for CI remote-only mode |
| `localDocsDiagnostic` | Yes | Local documentation availability diagnostic |
| `targets` | Yes | Product target metadata |
| `sample` | Yes | Ordered sampled case IDs |
| `cases` | Yes | Case definitions used in the run |
| `results` | Yes | Product result records |
| `issueCollection` | Yes | Issue collector outcome |

## Classification Enum

Allowed `classification` values:

- `symbol_hit`
- `module_only`
- `empty`
- `wrong_framework`
- `wrong_page`
- `unsupported_misclassified`
- `network_error`

## Verdict Enum

Allowed `verdict` values:

- `pass`
- `fail`
- `infra`
- `not_applicable`

## Product Summary

Reports must aggregate every product by verdict count:

- pass count
- fail count
- infrastructure count
- not-applicable count

## Failure Heatmap

Reports must group failures by:

- query shape
- framework/product area
- product
- classification

## iDocs Failure Rows

Every actionable iDocs failure row must include:

- case ID
- query
- expected outcome
- classification
- top evidence
- local reproduction command

## Cross-Product Comparison

For each sampled case, reports must present iDocs and all competitor targets side by side with classification, verdict, and top evidence.
