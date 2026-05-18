# Research: Robust DocC Identifier Fetch

## Decision: Keep `DocCContent.identifier` public shape as a string

**Decision**: Preserve the public documentation content identifier as a `String`, even when Apple remote JSON supplies identifier metadata as an object.

**Rationale**: Existing cache payloads, fixtures, renderers, adapter output, and tests all treat the identifier as a stable string. Changing it to a public struct would widen the blast radius and force avoidable downstream migrations.

**Alternatives considered**:
- Replace `identifier` with a public metadata struct. Rejected because it would be a breaking API/cache shape change for a narrow compatibility issue.
- Add a second public identifier field. Rejected because callers need one canonical identifier and the object shape only contributes its URL.

## Decision: Decode both old and current identifier shapes, encode only the stable string shape

**Decision**: Decode identifier first as a string, then as structured metadata containing `url`. Continue encoding `DocCContent.identifier` as a string.

**Rationale**: String-first decoding preserves old fixture/cache compatibility. String-only encoding keeps disk cache and test helper output stable after content has been normalized.

**Alternatives considered**:
- Encode the original shape back out. Rejected because `DocCContent` does not preserve source-shape metadata and cache stability is more important than round-tripping Apple input representation.
- Decode only the object shape. Rejected because existing local/cache content and fixtures would fail.

## Decision: Treat missing object URL as a decode failure

**Decision**: Structured identifier metadata without `url` is invalid documentation content and should continue through the existing remote decode failure path.

**Rationale**: Without a URL, iDocs cannot derive the externally visible identifier promised by the model. Accepting an empty or synthetic identifier would hide upstream schema problems and weaken diagnostics.

**Alternatives considered**:
- Use an empty string or fallback path as identifier. Rejected because it creates misleading content and makes malformed Apple payloads look valid.
- Ignore identifier entirely. Rejected because identifier remains part of the public content model.

## Decision: Do not change fetch source order or fallback behavior

**Decision**: Keep the existing `cache -> local -> apple -> sosumi` source chain and only change whether valid Apple DocC JSON is accepted.

**Rationale**: The bug is a content decoding incompatibility, not a fetch routing issue. Reordering sources would risk unrelated behavior changes.

**Alternatives considered**:
- Skip Apple after object identifier decode failure and prefer sosumi. Rejected because current Apple payload is valid and should be the authoritative source.
- Add a special retry path for object identifiers. Rejected because the same decoder should handle the payload on the first Apple attempt.
