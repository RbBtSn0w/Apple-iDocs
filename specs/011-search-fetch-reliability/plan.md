# Implementation Plan: Search and Fetch Reliability for Mixed Apple Documentation Sources

**Branch**: `011-search-fetch-reliability` | **Date**: Monday, May 11, 2026 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `specs/011-search-fetch-reliability/spec.md`

## Summary

Extend the existing `idocs` CLI-only lookup pipeline so mixed Apple documentation sources are classified at search time, fetchability is visible before fetch, local-source degradation is machine-readable, broad-query fallback provenance is preserved, and fetch results expose ordered source attempts. The implementation stays inside the current Swift CLI, adapter, and kit layers and keeps `idocs search -> idocs fetch` as the default evidence path.

## Technical Context

**Language/Version**: Swift 6.0 project settings  
**Primary Dependencies**: `swift-argument-parser`, `swift-log`, Foundation `URLSession`/`FileManager`; no new runtime service dependencies  
**Storage**: Existing memory cache for search, disk cache for fetched content, optional JSONL usage log  
**Testing**: Swift Testing via the shared Tuist `iDocs` scheme  
**Target Platform**: macOS CLI  
**Project Type**: CLI plus adapter/library modules  
**Performance Goals**: Preserve current local/cache-first behavior; keep search/fetch diagnostics lightweight and avoid additional network attempts unless a broad-query fallback is needed  
**Constraints**: CLI-only runtime, deterministic cache -> local -> Apple -> sosumi order, stateless commands, no MCP/server transport in product runtime, sanitized diagnostics only  
**Scale/Scope**: Existing `search`, `fetch`, and JSON/text output contracts; no new commands

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Offline-First**: PASS. The existing lookup order remains cache/local before remote. New diagnostics report local degradation instead of bypassing local sources.
- **Stateless CLI/Adapter Design**: PASS. The feature adds metadata to existing command responses without session state or command ordering requirements.
- **Test-First**: PASS. Tasks require failing Swift Testing coverage before implementation for each story.
- **Observability**: PASS. Search and fetch source attempts become structured diagnostics and usage-log candidates.
- **Simplicity**: PASS. No new CLI command or service process; page-family classification is pure path/URL metadata.
- **Native Swift First**: PASS. HTML help extraction uses Foundation networking and parsing helpers, not external runtimes.
- **Type Safety**: PASS. New metadata is represented by Swift enums/structs and mapped through adapter/CLI payload types.
- **Agent Memory Boundary**: PASS. AGENTS.md is updated only to point at this plan; architecture remains in Constitution/spec artifacts.

## Project Structure

### Documentation (this feature)

```text
specs/011-search-fetch-reliability/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── cli-output.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/
├── iDocsKit/
│   ├── DataSources/
│   │   ├── AppleJSONAPI.swift
│   │   ├── AppleHelpAPI.swift
│   │   └── SosumiAPI.swift
│   ├── Rendering/
│   │   └── DocCTypes.swift
│   ├── Tools/
│   │   ├── FetchDocTool.swift
│   │   └── SearchDocsTool.swift
│   ├── Utils/
│   │   ├── DocumentationUsageRecorder.swift
│   │   └── URLHelpers.swift
│   └── Protocols/
│       └── InternalProtocols.swift
├── iDocsAdapter/
│   ├── Adapters/
│   │   ├── DefaultDocumentationAdapter.swift
│   │   └── MockDocumentationAdapter.swift
│   └── Models/
│       ├── CoreEntities.swift
│       └── DocumentationError.swift
└── iDocsApp/
    └── Commands/
        ├── CLIExecutor.swift
        └── CLIOutputModels.swift

Tests/
├── iDocsTests/
│   ├── ToolTests.swift
│   ├── FetchDocToolTests.swift
│   ├── CLICommandTests.swift
│   └── UsageLoggingTests.swift
└── iDocsAdapterTests/
    └── DocumentationServiceContractTests.swift
```

**Structure Decision**: Use the existing three-layer split. `iDocsKit` owns source classification, query attempts, help fetch, and source-attempt diagnostics. `iDocsAdapter` maps typed kit results into stable adapter entities. `iDocsApp` serializes the CLI text/JSON contract.

## Phase 0: Research

See [research.md](./research.md). All planning questions were resolved without formal clarification questions.

## Phase 1: Design & Contracts

See [data-model.md](./data-model.md), [contracts/cli-output.md](./contracts/cli-output.md), and [quickstart.md](./quickstart.md).

## Post-Design Constitution Check

- **Offline-First**: PASS. Fetch still tries disk cache and local Xcode docs before remote. Search still tries memory cache and local docs before remote. Query normalization is limited to fallback search after higher-priority sources miss.
- **Stateless CLI/Adapter Design**: PASS. Metadata is returned per invocation; no persistent session state is introduced.
- **Test-First**: PASS. `tasks.md` places failing tests before implementation.
- **Observability**: PASS. Search diagnostics and fetch attempts provide structured source categories, reasons, hints, and sanitized metadata.
- **Simplicity**: PASS. The design adds one focused Help-page fetch adapter and explicit unsupported classification; it does not add a browser, server, MCP runtime, or new command.
- **Native Swift First**: PASS. The design uses Foundation networking/string parsing and existing Swift modules.
- **Type Safety**: PASS. Output contracts map from typed Swift entities.
- **Agent Memory Boundary**: PASS. AGENTS.md plan pointer is updated; architecture details remain in this plan and spec artifacts.

## Complexity Tracking

No Constitution violations.
