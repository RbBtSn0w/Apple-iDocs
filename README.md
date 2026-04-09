# iDocs: Swift-Native Apple Documentation CLI

iDocs is a high-performance Swift CLI for querying Apple's documentation, rendering Markdown output, and listing technology catalogs.

## Features

- **Search Docs**: Global search across Apple's documentation catalog.
- **Fetch Doc**: Get high-quality Markdown content for any documentation path.
- **Xcode Local Docs**: Access documentation already downloaded by Xcode (supports offline mode).
- **Browse Technologies**: Explore Apple's framework and technology catalog.
- **Intelligent Caching**: Layered memory and disk caching for maximum performance.
- **Deterministic Source Chain**: `cache -> local(Xcode) -> apple -> sosumi` for `search`/`fetch`.

## Installation

### Prerequisites
- macOS 13.0+
- Xcode 15.0+
- [Tuist](https://tuist.io): `curl -Ls https://install.tuist.io | bash`

### Setup and Build
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

### npm Distribution (macOS arm64)

Global install:

```bash
npm install -g idocs-cli
idocs --help
```

The npm wrapper downloads `idocs-darwin-arm64.tar.gz` from GitHub Releases during `postinstall`.
You can override the download base URL:

```bash
export IDOCS_RELEASE_BASE_URL="https://github.com/<owner>/<repo>/releases/download/v{version}"
npm install -g idocs-cli
```

Local registration for development:

```bash
./scripts/tuist-silent.sh build iDocs
npm --prefix npm run link-local
npm --prefix npm link
idocs --help
```

Local tgz smoke test:

```bash
(cd npm && npm pack)
TMP_DIR="$(mktemp -d)"
npm --prefix "$TMP_DIR" init -y
npm --prefix "$TMP_DIR" i "$(pwd)/npm/idocs-cli-0.1.0.tgz"
IDOCS_LOCAL_BINARY="$HOME/Library/Developer/Xcode/DerivedData/iDocs-codex/Build/Products/Debug/idocs" \
  npm --prefix "$TMP_DIR/node_modules/idocs-cli" run link-local
"$TMP_DIR/node_modules/.bin/idocs" --help
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
./scripts/tuist-silent.sh test-all
```

Notes:
- This workflow wraps `xcodebuild` directly and prints only summary lines on success.
- If `iDocs.xcworkspace` is missing, it attempts `tuist generate` automatically.
- It does not require opening Xcode IDE.
- On failures, it prints recent logs for quick diagnostics.
- `./scripts/tuist-silent.sh test` and benchmark scripts should run serially unless you set a separate `IDOCS_DERIVED_DATA_PATH`, otherwise Xcode may lock `build.db`.

## Usage

### CLI
```bash
./scripts/tuist-silent.sh run idocs --help
```

### Subcommands
```bash
./scripts/tuist-silent.sh run idocs search "SwiftUI"
./scripts/tuist-silent.sh run idocs fetch "/documentation/swiftui/view"
./scripts/tuist-silent.sh run idocs list
```

Notes:
- Search output includes source markers like `{source: apple}`.
- Fetch output includes a source header like `[source: local|apple|sosumi|cache]`.

## Testing

Default tests (offline, no external network):

```bash
./scripts/tuist-silent.sh test
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
- Integration tests validate live endpoints and may fail if services are unavailable

## Quality Gates

```bash
./scripts/arch-gate.sh
./scripts/spec-trace-gate.sh
./scripts/coverage-gate.sh 60
./scripts/e2e-cli.sh
```

Notes:
- `spec-trace-gate.sh` verifies every `FR-*`/`SC-*` in `spec.md` has a mapped automated check.
- `coverage-gate.sh` runs `xcodebuild` with coverage and evaluates average line coverage for `iDocsKit`, `iDocsAdapter`, and `iDocsApp`.

## License
MIT

## Community

- Code of Conduct: [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)
- Contributing Guide: [CONTRIBUTING.md](./CONTRIBUTING.md)
- Security Policy: [SECURITY.md](./SECURITY.md)
