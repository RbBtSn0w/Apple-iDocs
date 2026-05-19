# Research: Resilient DocC Ingestion

## Decision: Add an internal tolerant ingestion layer instead of loosening public models

**Decision**: Decode Apple remote payloads through an internal tolerant layer and normalize them into stable `DocCContent`.

**Rationale**: Apple remote DocC JSON is an internal web payload and can drift. iDocs callers need a stable public contract, not Apple-specific raw schema.

**Alternatives considered**:
- Change public `DocCContent` to mirror Apple raw schema. Rejected because it breaks cache, renderers, and adapter callers.
- Decode everything as raw Markdown from sosumi. Rejected because it gives up iDocs' Apple-first evidence boundary.

## Decision: Use typed `JSONValue`, not `[String: Any]` or a third-party AnyCodable dependency

**Decision**: Introduce a local `JSONValue` enum for objects, arrays, strings, numbers, booleans, and nulls.

**Rationale**: `JSONValue` stays Codable, Sendable, Equatable, and testable. It satisfies the constitution's type-safety rule while still accepting unknown Apple shapes.

**Alternatives considered**:
- `[String: Any]`: Rejected because it is not Codable/Sendable and pushes runtime casts into normalizer and renderer code.
- Third-party AnyCodable/BetterCodable: Rejected because the main work is normalization and diagnostics, not merely storing unknown JSON.

## Decision: Required core strictness plus non-critical partial tolerance

**Decision**: Require usable title and identifier/path plus at least one meaningful renderable content source. Unknown non-critical content is skipped with diagnostics.

**Rationale**: This prevents misleading evidence while avoiding unnecessary fallback when Apple content is mostly usable.

**Alternatives considered**:
- Accept payloads with only a title. Rejected because that is not enough evidence for agents.
- Fail on every unknown node. Rejected because it reproduces the current schema-drift fragility.

## Decision: Path-aware diagnostics stay on the fetch source attempt

**Decision**: Add diagnostic reason/hint values such as `remote_decode_partial.primaryContentSections[0].content[2]` or `remote_decode_failed.metadata.title` to Apple source attempts.

**Rationale**: The existing fetch result surface already reports source attempts. Enriching those attempts preserves CLI compatibility and makes future schema drift actionable.

**Alternatives considered**:
- Add a new top-level diagnostics array. Rejected for this feature because it changes more output surface than needed.
- Keep only `remote_decode_failed`. Rejected because it slows triage when Apple changes shape.
