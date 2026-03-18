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
   tuist build iDocs
   ```

The binary will be located in the build directory.

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
tuist test iDocs
```

Integration tests (explicitly enabled):

```bash
IDOCS_INTEGRATION_TESTS=1 tuist test iDocs
```

```bash
swift test --filter IntegrationTests
```

Notes:
- Default tests do not access external networks
- Integration tests validate live endpoints and may fail if services are unavailable

## License
MIT
