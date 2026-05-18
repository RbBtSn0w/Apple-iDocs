# Contract: Fetch DocC Identifier Compatibility

## Capability

`idocs fetch` remains the canonical evidence capability for known documentation paths.

## Accepted Identifier Inputs

### String Identifier

```json
{
  "identifier": "doc://com.apple.documentation/documentation/swiftui/view"
}
```

Expected behavior:

- Accepted as valid DocC content.
- Returned content exposes the same identifier string.
- Stored/encoded content keeps `identifier` as a string.

### Object Identifier

```json
{
  "identifier": {
    "url": "doc://com.apple.documentation/documentation/swiftui/view",
    "interfaceLanguage": "swift"
  }
}
```

Expected behavior:

- Accepted as valid DocC content.
- Returned content exposes `doc://com.apple.documentation/documentation/swiftui/view` as the identifier string.
- Stored/encoded content keeps `identifier` as a string.
- No new public field is exposed for `interfaceLanguage`.

### Invalid Object Identifier

```json
{
  "identifier": {
    "interfaceLanguage": "swift"
  }
}
```

Expected behavior:

- Rejected as invalid DocC content.
- Apple source attempt records `remote_decode_failed`.
- Existing fallback behavior continues.

## Source Attempt Contract

For cache and local misses followed by valid Apple object-identifier content:

```text
cache -> local -> apple
```

Expected selected source:

```text
apple
```

Expected absent source:

```text
sosumi
```

For invalid Apple content:

```text
cache -> local -> apple(remote_decode_failed) -> sosumi
```

Fallback success or failure follows existing fetch behavior.
