# Quickstart: Robust DocC Identifier Fetch

## Prerequisites

- macOS development environment.
- Tuist available through the project scripts.
- No live network requirement for the default test suite.

## Run Full Swift Tests

```bash
./scripts/tuist-silent.sh test
```

Expected outcome:

- Fetch tests pass for string identifiers.
- Fetch tests pass for Apple object-shaped identifiers.
- Invalid remote content still records `remote_decode_failed` and falls back as before.

## Optional Live Fetch Smoke

```bash
./scripts/tuist-silent.sh run idocs fetch /documentation/swiftui/navigationsplitview --json
```

Expected outcome:

- Preferred: `source` is `apple` when Apple remote DocC JSON is reachable.
- At minimum: any Apple attempt failure is not caused by inability to decode the top-level identifier object.

## Focused Test Intent

The implementation should be provable with tests that cover:

- Apple remote DocC JSON with object-shaped identifier succeeds from Apple.
- Source attempts for that success are cache, local, Apple only.
- Existing string identifier JSON still succeeds.
- Re-encoded content still writes identifier as a string.
- Object identifier without URL still produces remote decode failure and fallback behavior.
