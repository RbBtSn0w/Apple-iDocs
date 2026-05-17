# Contract: DocumentationService Resolve Boundary

## Protocol Requirement

The adapter boundary exposes structured resolution:

```swift
func resolve(intent: ResolveIntent, config: DocumentationConfig) async throws -> ResolveResult
```

## Behavioral Requirements

- Uses the same behavior as `idocs resolve`.
- Preserves caller context from `DocumentationConfig`.
- Returns typed confidence, evidence, candidates, resolver diagnostics, and fetch diagnostics.
- Does not mutate global or session state.
- Does not require `search` or `fetch` to be called first.
- May use search fallback internally, but only after direct path resolution fails or is ambiguous.

## Mock Requirements

`MockDocumentationAdapter` must support deterministic resolve results and errors so CLI and contract tests can exercise:

- High-confidence direct fetch-verified result.
- Invalid structured intent.
- Unresolved result with diagnostics.

## Contract Tests

Contract tests must prove:

- A stub service can implement the resolve API shape.
- `MockDocumentationAdapter` returns configured resolve results.
- Search/fetch/list behavior remains source compatible for existing tests.
