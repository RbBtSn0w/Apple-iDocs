# Contract: Apple Remote DocC Ingestion

## Successful Partial Apple Fetch

Input shape:

```json
{
  "identifier": { "url": "doc://com.apple.SwiftUI/documentation/SwiftUI/NavigationSplitView" },
  "metadata": { "title": "NavigationSplitView" },
  "abstract": [{ "type": "text", "text": "A split navigation view." }],
  "primaryContentSections": [
    {
      "kind": "content",
      "content": [
        { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "Known text." }] },
        { "type": "newAppleBlock", "payload": { "unexpected": true } }
      ]
    }
  ]
}
```

Expected fetch behavior:

```text
source = apple
source_attempts = cache, local, apple
apple.reason = remote_decode_partial.primaryContentSections[0].content[1]
```

Expected output:

- Markdown includes `# NavigationSplitView`.
- Markdown includes `Known text.`
- Fallback source is not attempted.
- Cache stores stable `DocCContent` output.

## Required Core Failure

Input shape:

```json
{
  "identifier": { "interfaceLanguage": "swift" },
  "metadata": {},
  "primaryContentSections": []
}
```

Expected fetch behavior:

```text
source_attempts = cache, local, apple, sosumi
apple.reason = remote_decode_failed.metadata.title
```

Fallback behavior follows the existing sosumi success/failure path.

## Stable Output Contract

Encoded normalized content must keep stable fields:

```json
{
  "identifier": "doc://com.apple.SwiftUI/documentation/SwiftUI/NavigationSplitView",
  "metadata": {
    "title": "NavigationSplitView"
  }
}
```

Raw `JSONValue` objects must not appear in encoded content.
