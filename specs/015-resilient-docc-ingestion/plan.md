# Implementation Plan: Resilient DocC Ingestion

**Branch**: `015-resilient-docc-ingestion` | **Date**: Tuesday, May 19, 2026 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/015-resilient-docc-ingestion/spec.md`

## Summary

Add a Swift-native tolerant Apple remote DocC ingestion boundary that can normalize Apple payloads with unknown non-critical nodes into the existing stable `DocCContent` model. The design uses a typed `JSONValue` representation at the remote ingestion edge, keeps public/cache output stable, records path-aware partial decode diagnostics, and preserves the existing `cache -> local -> apple -> sosumi` fetch chain.

## Technical Context

**Language/Version**: Swift 6.0 project settings
**Primary Dependencies**: Tuist, Foundation, swift-argument-parser, swift-log, existing iDocsKit fetch/data-source/rendering stack
**Storage**: Existing fetch disk cache only; normalized successful Apple content encodes to stable `DocCContent` shape
**Testing**: `./scripts/tuist-silent.sh test`; optional temporary-cache live smoke through `IDOCS_CACHE_PATH=$(mktemp -d ...) ./scripts/tuist-silent.sh run idocs fetch /documentation/swiftui/navigationsplitview --json`
**Target Platform**: macOS CLI and macOS CI runner
**Project Type**: Swift CLI with adapter/library targets
**Performance Goals**: Avoid extra network calls when Apple remote payload has usable core evidence; fallback only when Apple cannot normalize usable content
**Constraints**: CLI-only runtime; no Node/Python/MCP/database dependency; no public `DocCContent` shape change; no `[String: Any]`; fetch source order preserved; diagnostics remain machine-readable
**Scale/Scope**: Apple remote DocC payload ingestion only. Cache/local stable decode stays unchanged except for shared model compatibility.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Offline-first chain**: PASS. Cache and local remain before Apple; sosumi remains fallback after Apple cannot produce usable content.
- **Stateless CLI/Adapter boundary**: PASS. No CLI state or adapter contract changes are introduced.
- **Agent Evidence Entry**: PASS. `fetch` remains canonical path evidence authority; `resolve` and `search` responsibilities are unchanged.
- **TDD evidence**: PASS. Tasks require RED tests for tolerant Apple success, stable encode shape, path-aware partial diagnostics, and required-core fallback.
- **Observability**: PASS. Fetch diagnostics gain path-aware partial/failure reasons without removing existing source attempts.
- **Simplicity**: PASS. The tolerant layer is internal and targeted; no service, database, embedding, or full DocC schema rewrite.
- **Native Swift first**: PASS. Implementation uses Foundation and typed Swift enums/structs only.
- **Type safety**: PASS. Unknown JSON is represented by `JSONValue`, not `Any` or `AnyObject`, and normalized into typed stable models.
- **Agent memory boundary**: PASS. This plan updates only feature guidance and generated Spec Kit artifacts.

## Project Structure

### Documentation (this feature)

```text
specs/015-resilient-docc-ingestion/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── apple-remote-ingestion.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/
└── iDocsKit/
    ├── DataSources/
    │   └── AppleJSONAPI.swift
    ├── Rendering/
    │   ├── AppleDocCIngestion.swift
    │   ├── DocCRenderer.swift
    │   └── DocCTypes.swift
    └── Tools/
        └── FetchDocTool.swift

Tests/
└── iDocsTests/
    ├── AppleDocCIngestionTests.swift
    ├── FetchDocToolTests.swift
    └── TestSupport/
        └── MockPayloads.swift
```

**Structure Decision**: Place tolerant ingestion in `iDocsKit/Rendering` because it transforms upstream DocC JSON into renderer-ready content. Keep network fetching in `AppleJSONAPI` and source-chain orchestration in `FetchDocTool`.

## Phase 0: Research

See [research.md](./research.md). Planning decisions are resolved without open clarification markers.

## Phase 1: Design & Contracts

See [data-model.md](./data-model.md), [contracts/apple-remote-ingestion.md](./contracts/apple-remote-ingestion.md), and [quickstart.md](./quickstart.md).

## Post-Design Constitution Check

- **Offline-first chain**: PASS. Source order remains unchanged and tests assert fallback is not called on partial Apple success.
- **Stateless CLI/Adapter boundary**: PASS. No new command or caller state is required.
- **Agent Evidence Entry**: PASS. The feature improves `fetch` evidence quality for known paths.
- **TDD evidence**: PASS. Tasks map each story to RED tests before production changes.
- **Observability**: PASS. Partial/failure diagnostics include JSON paths on Apple attempts.
- **Simplicity**: PASS. The initial normalizer covers core renderable content and skips unknown nodes; broader schema support remains incremental.
- **Native Swift first**: PASS. No new dependency or runtime is introduced.
- **Type safety**: PASS. `JSONValue` and normalization types are explicit and testable.
- **Agent memory boundary**: PASS. `AGENTS.md` is updated only with this plan reference.

## Complexity Tracking

No constitution violations requiring exception.
