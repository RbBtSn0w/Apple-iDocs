# Quickstart: Search Quality Race CI

## Prerequisites

- macOS development shell.
- Tuist available through the repository setup script.
- Node.js available through the local shell or CI setup.
- GitHub CLI authenticated only when testing live issue mutation.

## Generate and Build

```bash
tuist generate --no-open
./scripts/tuist-silent.sh build iDocs
```

## Run Swift Tests

```bash
./scripts/tuist-silent.sh test
```

## Run Node Script Tests

```bash
node --test scripts/benchmark/tests/*.test.mjs
```

## Run a Local Mock Audit

```bash
node scripts/benchmark/run-random-search-audit.mjs \
  --seed 1 \
  --sample-size 6 \
  --mock-targets scripts/benchmark/fixtures/mock-target-results.json \
  --output-dir /tmp/idocs-search-quality-race
```

Expected outputs:

- `/tmp/idocs-search-quality-race/random-search-audit.json`
- `/tmp/idocs-search-quality-race/random-search-audit.md`

## Render a Summary

```bash
node scripts/benchmark/render-search-quality-summary.mjs \
  --input /tmp/idocs-search-quality-race/random-search-audit.json \
  --output /tmp/idocs-search-quality-race/summary.md
```

## Dry-Run Issue Collection

```bash
node scripts/benchmark/create-search-quality-issue.mjs \
  --input /tmp/idocs-search-quality-race/random-search-audit.json \
  --dry-run \
  --print-body
```

## Validate Remote-Only iDocs Behavior

```bash
IDOCS_XCODE_DOC_CACHE_PATH=/tmp/idocs-nonexistent-doc-cache \
  ./scripts/tuist-silent.sh run idocs search "SwiftUI NavigationSplitView" --json
```

Expected behavior:

- Search continues through remote sources.
- JSON diagnostics include a local-documentation-unavailable signal.

## Manual CI Validation

Use the `Search Quality Race` GitHub Actions workflow with:

- `seed`: `1`
- `sample_size`: `6`
- `mock_failure`: `false` for no-op issue path

Then repeat with `mock_failure=true` to validate issue body generation and fingerprint de-duplication.
