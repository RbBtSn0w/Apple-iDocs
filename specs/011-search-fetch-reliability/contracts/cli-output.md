# CLI Output Contract: Mixed Apple Documentation Source Reliability

## Search JSON

Command:

```sh
idocs search "Xcode Cloud TestFlight App Store Connect" --json
```

Each item in `results` keeps existing fields and adds:

```json
{
  "id": "/help/app-store-connect/manage-builds/upload-builds",
  "title": "Upload builds",
  "snippet": "Upload builds to App Store Connect.",
  "technology": "app-store-connect",
  "source": "sosumi",
  "source_kind": "help",
  "fetch_supported": true,
  "fetch_support_reason": null,
  "query_attempt": "Xcode Cloud TestFlight App Store Connect"
}
```

Rules:

- `source_kind` is always present.
- `fetch_supported` is always present.
- `fetch_support_reason` is present when `fetch_supported` is false.
- `query_attempt` identifies which original or derived query produced the result.

## Search Diagnostics JSON

`search_diagnostics` keeps existing fields and may add `query_attempt`:

```json
{
  "name": "local",
  "status": "miss",
  "duration_ms": 1.0,
  "result_count": 0,
  "reason": "local_docs_unavailable",
  "hint": "Xcode local documentation is unavailable; this run is remote-only.",
  "query_attempt": "Xcode Cloud TestFlight App Store Connect"
}
```

Rules:

- Missing local documentation is a structured diagnostic, not only free text.
- Remote and fallback stages identify the query attempt when relevant.

## Fetch JSON

Command:

```sh
idocs fetch /documentation/xcode/environment-variable-reference --json
```

Successful fallback output keeps existing fields and adds `fetch_diagnostics`:

```json
{
  "command": "fetch",
  "id": "/documentation/xcode/environment-variable-reference",
  "source": "sosumi",
  "body": "# Environment variable reference\n...",
  "fetch_diagnostics": [
    {
      "source": "apple",
      "status": "error",
      "reason": "remote_decode_failed",
      "status_code": 200,
      "content_type": "application/json"
    },
    {
      "source": "sosumi",
      "status": "hit"
    }
  ]
}
```

Aggregate failure output:

```json
{
  "command": "fetch",
  "id": "/documentation/appstoreconnectapi",
  "exit_category": "NETWORK",
  "error_message": "Error [NETWORK]: apple: remote_decode_failed; sosumi: http_500",
  "fetch_diagnostics": [
    {
      "source": "apple",
      "status": "error",
      "reason": "remote_decode_failed"
    },
    {
      "source": "sosumi",
      "status": "error",
      "reason": "http_500",
      "status_code": 500
    }
  ]
}
```

Unsupported output:

```json
{
  "command": "fetch",
  "id": "/videos/play/wwdc2024/10123",
  "exit_category": "CONFIG",
  "error_message": "Error [CONFIG]: Unsupported Apple source type for '/videos/play/wwdc2024/10123'.",
  "fetch_diagnostics": [
    {
      "source": "unsupported",
      "status": "unsupported",
      "reason": "unsupported_source_type"
    }
  ]
}
```

Rules:

- `fetch_diagnostics` is present on fetch success and fetch failure when source attempts are known.
- Real but unsupported Apple page families must not return `NOT_FOUND`.

## Text Output

Search text output includes compact markers:

```text
- Upload builds [app-store-connect] {source: sosumi, kind: help, fetch: supported}
  - ID: /help/app-store-connect/manage-builds/upload-builds
```

Fetch text output keeps the source marker and may include diagnostics when fallback occurred:

```text
[source: sosumi]
[attempts: apple=remote_decode_failed, sosumi=hit]
# Environment variable reference
```
