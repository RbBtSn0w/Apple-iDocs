# iDocs: Swift-Native Apple Documentation MCP Server

iDocs is a high-performance Model Context Protocol (MCP) server written in Swift, designed to provide AI agents with seamless access to Apple's official documentation, HIG, and WWDC transcripts.

## Features

- **Search Docs**: Global search across Apple's documentation catalog.
- **Fetch Doc**: Get high-quality Markdown content for any documentation path.
- **Xcode Local Docs**: Access documentation already downloaded by Xcode (supports offline mode).
- **Browse Technologies**: Explore Apple's framework and technology catalog.
- **HIG Access**: Fetch Human Interface Guidelines content.
- **External DocC**: Fetch documentation from third-party Swift-DocC sites.
- **WWDC Transcripts**: Access video transcripts for WWDC sessions.
- **Dual Transport**: Supports both `stdio` (IDE integration) and `http` (distributed use) modes.
- **Intelligent Caching**: Layered memory and disk caching for maximum performance.

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

For MCP runtime:

```bash
./scripts/tuist-silent.sh run iDocsMCP --http --port 8080
```

Notes:
- This workflow uses `tuist xcodebuild ... -quiet` under the hood.
- It does not require opening Xcode IDE.
- Run output from your app/test still appears, while build noise is minimized.

## Usage

### Stdio Mode (Default)
Useful for integration with Claude Desktop or Cursor.
```bash
./idocs
```

### HTTP Mode
```bash
./idocs --http --port 8080
```

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

## MCP Tools

- `search_docs(query)`: Search documentation.
- `fetch_doc(path)`: Fetch documentation content.
- `xcode_docs(query, list)`: Query local Xcode documentation.
- `browse_technologies()`: List all technologies.
- `fetch_hig(topic)`: Get HIG content.
- `fetch_external_doc(url)`: Get third-party DocC content.
- `fetch_video_transcript(videoID)`: Get WWDC transcripts.

## Configuration for AI Clients

Add the following to your MCP settings:

```json
{
  "mcpServers": {
    "idocs": {
      "command": "/path/to/idocs",
      "args": []
    }
  }
}
```

## License
MIT
