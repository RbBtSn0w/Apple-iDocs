# Quickstart: Agent Resolve Documentation Entry

## Prerequisites

- macOS development environment.
- Tuist available through the project scripts.
- No live network requirement for the default test suite; live CLI smoke may use remote fallback when local docs/cache miss.

## Run Swift Tests

```bash
./scripts/tuist-silent.sh test
```

## Run Benchmark Script Tests

```bash
node --test scripts/benchmark/tests/*.test.mjs
```

## Resolver CLI Smokes

```bash
./scripts/tuist-silent.sh run idocs resolve \
  --framework SwiftUI \
  --symbol NavigationSplitView \
  --json
```

```bash
./scripts/tuist-silent.sh run idocs resolve \
  --framework AppKit \
  --type NSWindow \
  --member toolbarStyle \
  --member-kind property \
  --json
```

```bash
./scripts/tuist-silent.sh run idocs resolve \
  --framework UIKit \
  --type UIViewController \
  --member present \
  --member-kind method \
  --json
```

## Invalid Intent Smoke

```bash
./scripts/tuist-silent.sh run idocs resolve \
  --framework SwiftUI \
  --member body \
  --json
```

Expected outcome:

- Structured error.
- `confidence` is `unresolved`.
- `verified_by_fetch` is false.
- Natural-language search fallback is not used.

## Audit Layering Smoke

```bash
node scripts/benchmark/run-random-search-audit.mjs \
  --seed 13 \
  --sample-size 8 \
  --output-json /tmp/idocs-resolve-audit.json \
  --output-md /tmp/idocs-resolve-audit.md
```

Expected outcome:

- Audit cases include exactly one primary capability.
- Reports separate resolve, fetch, and search outcomes.
- P0 issue candidates exclude search exploration failures by default.
