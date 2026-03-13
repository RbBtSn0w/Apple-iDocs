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
- Xcode 15.0+ / Swift 6.0+

### Build from Source
```bash
swift build -c release
```

The binary will be located at `.build/release/iDocs`.

## Usage

### Stdio Mode (Default)
Useful for integration with Claude Desktop or Cursor.
```bash
./iDocs
```

### HTTP Mode
```bash
./iDocs --http --port 8080
```

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
      "command": "/path/to/iDocs",
      "args": []
    }
  }
}
```

## License
MIT
