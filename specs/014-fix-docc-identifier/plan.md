# Implementation Plan: Robust DocC Identifier Fetch

**Branch**: `014-fix-docc-identifier` | **Date**: Monday, May 18, 2026 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/014-fix-docc-identifier/spec.md`

## Summary

Fix `idocs fetch` so current Apple DocC JSON remains authoritative when the top-level `identifier` is an object containing a `url` field instead of the older string shape. The implementation keeps `DocCContent.identifier` as a string for callers, cache files, fixtures, and renderers; adds targeted Codable compatibility in `DocCContent`; and proves that `FetchDocTool.runDetailed` succeeds from Apple without falling through to sosumi when Apple returns the object-shaped identifier.

## Technical Context

**Language/Version**: Swift 6.0 project settings  
**Primary Dependencies**: Tuist, Foundation, swift-argument-parser, swift-log, existing iDocsKit fetch/data-source/rendering stack  
**Storage**: Existing fetch disk cache only; no cache format migration because encoded `DocCContent.identifier` remains a string  
**Testing**: Swift Testing through `./scripts/tuist-silent.sh test`; optional live fetch smoke through `./scripts/tuist-silent.sh run idocs fetch /documentation/swiftui/navigationsplitview --json`  
**Target Platform**: macOS CLI and macOS CI runner  
**Project Type**: Swift CLI with adapter/library targets  
**Performance Goals**: No additional network requests on successful Apple fetch; object identifier decoding should be local Codable work only  
**Constraints**: Preserve fetch source order `cache -> local -> apple -> sosumi`; preserve public `DocCContent.identifier: String`; do not introduce public API, runtime dependency, command, source, or renderer changes; malformed Apple content still reports `remote_decode_failed`  
**Scale/Scope**: One DocC schema compatibility fix for top-level `identifier`; no broader DocC payload schema expansion

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Offline-first chain**: PASS. Fetch continues to check cache and local content before Apple, then only uses sosumi when Apple does not produce valid documentation content.
- **Stateless CLI/Adapter boundary**: PASS. No CLI command or adapter method gains stateful preconditions; the existing fetch path remains single-call and input-complete.
- **Agent Evidence Entry**: PASS. This feature touches `fetch`, the canonical evidence authority for known paths. It does not alter `resolve` or reassign `search` responsibilities.
- **TDD evidence**: PASS. Tasks will add failing fetch tests for object identifier success and existing malformed remote fallback before implementation.
- **Observability**: PASS. Existing fetch source attempts and `remote_decode_failed` diagnostics are preserved.
- **Simplicity**: PASS. The fix is limited to targeted Codable compatibility and one fixture helper; no new command, service, source, or fallback logic is added.
- **Native Swift first**: PASS. Production runtime stays Swift/Foundation native and introduces no Node, Python, web server, or MCP dependency.
- **Type safety**: PASS. Compatibility is modeled with explicit Codable helper types rather than untyped dictionaries or erased values.
- **Agent memory boundary**: PASS. Architecture and operational boundaries remain in constitution/AGENTS; this plan only updates the current feature reference.

## Project Structure

### Documentation (this feature)

```text
specs/014-fix-docc-identifier/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── fetch-docc-identifier.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/
└── iDocsKit/
    └── Rendering/
        └── DocCTypes.swift

Tests/
└── iDocsTests/
    ├── FetchDocToolTests.swift
    ├── DocCTypesTests.swift
    └── TestSupport/
        └── MockPayloads.swift
```

**Structure Decision**: Keep the compatibility fix inside the existing DocC rendering/content model because both Apple remote fetches and cached/local DocC content already decode through `DocCContent`. Keep fetch behavior tests in `FetchDocToolTests` and fixture construction in `MockPayloads`.

## Phase 0: Research

See [research.md](./research.md). Planning decisions are resolved without open clarification markers.

## Phase 1: Design & Contracts

See [data-model.md](./data-model.md), [contracts/fetch-docc-identifier.md](./contracts/fetch-docc-identifier.md), and [quickstart.md](./quickstart.md).

## Post-Design Constitution Check

- **Offline-first chain**: PASS. The design changes only content decoding and leaves source attempt ordering untouched.
- **Stateless CLI/Adapter boundary**: PASS. Fetch callers keep the same path input and content output shape.
- **Agent Evidence Entry**: PASS. `fetch` remains the evidence authority and the fix makes Apple evidence reachable when the remote payload is valid.
- **TDD evidence**: PASS. The task plan must add RED tests for Apple object identifier success, string identifier compatibility, encoded string stability, and malformed identifier diagnostics.
- **Observability**: PASS. Apple decode failures continue to surface as `remote_decode_failed`; successful Apple fetches stop before sosumi.
- **Simplicity**: PASS. No broader DocC schema modeling or fallback reordering is introduced.
- **Native Swift first**: PASS. The implementation is Swift Codable only.
- **Type safety**: PASS. The object identifier is represented by a private typed decoding shape with required URL validation.
- **Agent memory boundary**: PASS. `AGENTS.md` is updated only to point to this feature plan.

## Complexity Tracking

No constitution violations requiring exception.
