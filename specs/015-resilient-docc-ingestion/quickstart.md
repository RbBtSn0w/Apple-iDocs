# Quickstart: Resilient DocC Ingestion

## Run Full Swift Tests

```bash
./scripts/tuist-silent.sh test
```

Expected outcome:

- Tolerant Apple remote payload tests pass.
- Existing fetch, render, cache, resolve, and adapter tests pass.

## Optional Live Fetch Smoke

```bash
IDOCS_CACHE_PATH="$(mktemp -d /tmp/idocs-015-cache.XXXXXX)" \
  ./scripts/tuist-silent.sh run idocs fetch /documentation/swiftui/navigationsplitview --json
```

Expected outcome:

- Preferred: `source` is `apple`.
- If Apple still cannot be normalized, the Apple source attempt should identify a path-aware failure reason that points to the next unsupported shape.

## Targeted Test Intent

- Unknown non-critical block does not force fallback.
- Unknown inline/reference shape produces partial diagnostics.
- Required core fields missing still falls back with path-aware failure.
- Encoded normalized content stays stable and raw JSON does not leak.
