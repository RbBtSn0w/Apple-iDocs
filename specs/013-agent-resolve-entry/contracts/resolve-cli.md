# Contract: `idocs resolve`

## Command

```bash
idocs resolve \
  --framework <framework> \
  [--symbol <symbol>] \
  [--type <type>] \
  [--member <member>] \
  [--member-kind <property|method|initializer|...>] \
  [--source-family documentation] \
  [--caller <opaque-caller>] \
  [--json]
```

## Valid Intent Shapes

- `--framework <framework> --symbol <symbol>`
- `--framework <framework> --type <type>`
- `--framework <framework> --type <type> --member <member> [--member-kind <kind>]`

Invalid structured intents return a structured error and must not run natural-language search fallback.

## JSON Success Shape

```json
{
  "command": "resolve",
  "caller": "skill.swiftui-engineering",
  "source_family": "documentation",
  "canonical_path": "/documentation/swiftui/navigationsplitview",
  "confidence": "high",
  "verified_by_fetch": true,
  "evidence": {
    "source_family": "documentation",
    "source": "apple",
    "path": "/documentation/swiftui/navigationsplitview",
    "title": "NavigationSplitView",
    "summary": "A view that presents views in columns."
  },
  "candidates": [
    {
      "path": "/documentation/swiftui/navigationsplitview",
      "title": "NavigationSplitView",
      "source": "direct",
      "match_quality": "exact",
      "verified_by_fetch": true,
      "confidence": "high"
    }
  ],
  "resolve_diagnostics": [
    {
      "stage": "direct_path",
      "status": "hit",
      "reason": "fetch_verified",
      "path_attempt": "/documentation/swiftui/navigationsplitview"
    }
  ],
  "fetch_diagnostics": [
    {
      "source": "apple",
      "status": "hit"
    }
  ],
  "error_message": null
}
```

## JSON Error Shape

```json
{
  "command": "resolve",
  "caller": "skill.swiftui-engineering",
  "source_family": "documentation",
  "canonical_path": null,
  "confidence": "unresolved",
  "verified_by_fetch": false,
  "evidence": null,
  "candidates": [],
  "resolve_diagnostics": [
    {
      "stage": "validation",
      "status": "error",
      "reason": "invalid_intent",
      "hint": "member requires type"
    }
  ],
  "fetch_diagnostics": null,
  "error_message": "Invalid resolve intent: member requires type."
}
```

## Compatibility Requirements

- `search`, `fetch`, and `list` JSON payloads keep their existing field semantics.
- Resolver-specific fields may be new fields or a new payload surface, but existing commands must not require consumers to parse them.
- Text output should remain concise and must show confidence plus canonical path or structured error.
