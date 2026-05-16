# Contract: Search Quality Race Workflow

## Triggers

The workflow must support:

- Nightly scheduled execution on the default branch.
- Manual dispatch with inputs for:
  - `seed`
  - `sample_size`
  - `package_spec`
  - `mock_failure`

## Permissions

The workflow must have enough permission to:

- Read repository contents.
- Create or update issues when actionable iDocs failures exist.

## Required Stages

The workflow must include these logical stages in order:

1. Checkout repository content.
2. Set up Tuist and Swift build dependencies.
3. Set up Node.js for benchmark scripts.
4. Build the current repository `idocs` CLI.
5. Install competitor npm releases and record exact resolved versions.
6. Run the random search audit in remote-only iDocs mode.
7. Render the GitHub run summary.
8. Publish complete artifacts.
9. Create or update repository issues when actionable iDocs golden-truth failures exist.

## Failure Semantics

The workflow must fail for infrastructure errors:

- iDocs build failure.
- Competitor package install or version-resolution failure.
- Audit runner crash.
- Report generation failure.
- Artifact publication failure.
- Required issue collection failure.

The workflow must not fail solely because:

- iDocs has golden-truth search failures.
- Competitors have failures.
- A case-level result is a network error and the runner can still complete.

## Remote-Only Contract

CI must configure iDocs so local Xcode documentation is unavailable for the race. The report must retain the local-documentation-unavailable diagnostic and state that local Xcode comparison is excluded.

## Outputs

Completed runs must produce:

- `random-search-audit.json`
- `random-search-audit.md`
- GitHub Step Summary sections:
  - Run metadata
  - Product summary
  - Failure heatmap
  - iDocs failures
  - Competitor comparison

## Security and Redaction

The workflow must not write secrets or sensitive environment values to summaries, artifacts, issue bodies, or comments.
