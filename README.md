# iDocs: Swift-Native Apple Documentation CLI

iDocs is a high-performance Swift CLI for querying Apple's documentation, rendering Markdown output, and listing technology catalogs.

The repository also contains project-scoped benchmark assets for external MCP services. Those assets exist only for comparison and validation; the shipped product runtime is CLI-only.

## Features

- **Search Docs**: Global search across Apple's documentation catalog.
- **Fetch Doc**: Get high-quality Markdown content for any documentation path.
- **Xcode Local Docs**: Access documentation already downloaded by Xcode (supports offline mode).
- **Browse Technologies**: Explore Apple's framework and technology catalog.
- **Intelligent Caching**: Layered memory and disk caching for maximum performance.
- **Deterministic Source Chain**: `cache -> local(Xcode) -> apple -> sosumi` for `search`/`fetch`.

## Installation

### Install from npm (recommended)

Requirements:
- macOS 13.0+
- Apple Silicon (`arm64`)
- Node.js 20+

Normal users only need:

```bash
npm install -g @rbbtsn0w/idocs
idocs --help
```

The npm wrapper downloads the matching CLI bundle from GitHub Releases during `postinstall`.
If install fails, treat it as a packaging problem and inspect the npm output.

### Build from source (development)

Prerequisites:
- macOS 13.0+
- Xcode 15.0+
- [Tuist](https://tuist.io): `curl -Ls https://install.tuist.io | bash`

Setup and build:
1. Clone the repository.
2. Resolve dependencies:
   ```bash
   tuist install
   ```
3. Generate project:
   ```bash
   tuist generate
   ```
4. Build:
   ```bash
   ./scripts/tuist-silent.sh build iDocs
   ```

The binary will be located in the build directory.

### Local npm development

Link the locally built binary into the npm wrapper:

```bash
./scripts/tuist-silent.sh build iDocs
npm --prefix npm run link-local
npm --prefix npm link
idocs --help
```

Local tgz smoke test:

```bash
TMP_DIR="$(mktemp -d)"
npm --prefix "$TMP_DIR" init -y
TGZ_FILE="$(cd npm && npm pack --silent)"
npm --prefix "$TMP_DIR" i "$(pwd)/npm/$TGZ_FILE"
IDOCS_LOCAL_BINARY="${PWD}/.deriveddata/Build/Products/Debug/idocs" \
  npm --prefix "$TMP_DIR/node_modules/@rbbtsn0w/idocs" run link-local
"$TMP_DIR/node_modules/.bin/idocs" --help
```

If you intentionally want a wrapper-only install for local debugging, opt out of fail-fast explicitly:

```bash
IDOCS_NPM_STRICT_INSTALL=0 npm install -g @rbbtsn0w/idocs
```

Unified E2E validation (link + pack paths):

```bash
./scripts/e2e-cli.sh offline
```

Live E2E validation (network-dependent, non-deterministic):

```bash
./scripts/e2e-cli.sh live
```

Release packaging for GitHub Releases:

```bash
./scripts/release-package.sh
```

### Silent CLI Workflow (No Xcode IDE)

Use the helper script to run build/test/run quietly from terminal:

```bash
./scripts/tuist-silent.sh build iDocs
./scripts/tuist-silent.sh run idocs --help
./scripts/tuist-silent.sh test
./scripts/tuist-silent.sh test iDocsAdapterTests
./scripts/tuist-silent.sh test-all
```

Notes:
- This workflow wraps `xcodebuild` directly and prints only summary lines on success.
- `./scripts/tuist-silent.sh test` runs the full default suite (`iDocsTests` + `iDocsAdapterTests`).
- If `iDocs.xcworkspace` is missing, it attempts `tuist generate` automatically.
- It does not require opening Xcode IDE.
- On failures, it prints recent logs for quick diagnostics.
- `./scripts/tuist-silent.sh test` and benchmark scripts should run serially unless you set a separate `IDOCS_DERIVED_DATA_PATH`, otherwise Xcode may lock `build.db`.

## Usage

### CLI
```bash
idocs --help
```

### Subcommands
```bash
idocs search "SwiftUI"
idocs fetch "/documentation/swiftui/view"
idocs list
```

Notes:
- Search output includes source markers like `{source: apple}`.
- Fetch output includes a source header like `[source: local|apple|sosumi|cache]`.
- For source-checkout workflows, replace `idocs` with `./scripts/tuist-silent.sh run idocs --`.
- Agent and benchmark workflows can override cache or usage-log locations with `IDOCS_CACHE_PATH` and `IDOCS_USAGE_LOG_PATH`.

## Testing

Default tests (offline, no external network):

```bash
./scripts/tuist-silent.sh test
```

Scoped runs:

```bash
./scripts/tuist-silent.sh test iDocsTests
./scripts/tuist-silent.sh test iDocsAdapterTests
```

Integration tests (explicitly enabled):

```bash
IDOCS_INTEGRATION_TESTS=1 ./scripts/tuist-silent.sh test
```

```bash
swift test --filter IntegrationTests
```

Notes:
- Default tests do not access external networks
- Default tests cover both CLI and Adapter test targets
- Integration tests validate live endpoints and may fail if services are unavailable

## Quality Gates

```bash
./scripts/arch-gate.sh
./scripts/spec-trace-gate.sh
./scripts/coverage-gate.sh 60
./scripts/e2e-cli.sh
./scripts/benchmark/check-local-cli-latency.sh
```

Notes:
- `spec-trace-gate.sh` verifies every `FR-*`/`SC-*` in `spec.md` has a mapped automated check.
- `coverage-gate.sh` runs `xcodebuild` with coverage and evaluates average line coverage for `iDocsKit`, `iDocsAdapter`, and `iDocsApp`.
- `check-local-cli-latency.sh` runs a local binary directly, records usage JSONL in an isolated cache/log location, and fails if the current p50/p95 thresholds regress.
- `check-local-cli-latency.sh` honors `IDOCS_LATENCY_SAMPLES`, `IDOCS_LATENCY_COMMAND_TIMEOUT_SECONDS`, `IDOCS_LATENCY_KEEP_ARTIFACTS`, `IDOCS_LATENCY_CACHE_DIR`, and `IDOCS_LATENCY_USAGE_LOG` for local diagnostics.

## License
MIT

## Community

- Code of Conduct: [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)
- Contributing Guide: [CONTRIBUTING.md](./CONTRIBUTING.md)
- Security Policy: [SECURITY.md](./SECURITY.md)
