# Implementation Plan: Agent Resolve Documentation Entry

**Branch**: `013-agent-resolve-entry` | **Date**: Saturday, May 16, 2026 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `specs/013-agent-resolve-entry/spec.md`

## Summary

Add `idocs resolve` as the P0 structured Apple documentation evidence entry for AI agents. The implementation adds typed resolve intent/result models to the adapter boundary, introduces an iDocsKit resolver that synthesizes canonical documentation paths and verifies every authoritative candidate through `FetchDocTool.runDetailed`, wires the CLI JSON/text output, and reframes the existing Search Quality Race scripts into a capability-layered evidence audit. `fetch` remains the evidence authority and `search` remains exploration/candidate discovery.

## Technical Context

**Language/Version**: Swift 6.0 project settings plus Node.js ES modules for benchmark scripts  
**Primary Dependencies**: Tuist, swift-argument-parser, swift-log, Foundation, existing iDocsKit data sources/tools, Node.js built-in test runner  
**Storage**: Existing disk cache for fetch; benchmark fixture JSON under `specs/008-mcp-service-benchmark/fixtures/`; no new persistent service storage  
**Testing**: `./scripts/tuist-silent.sh test`; `node --test scripts/benchmark/tests/*.test.mjs`; CLI smoke through `./scripts/tuist-silent.sh run idocs resolve ... --json`  
**Target Platform**: macOS CLI and macOS CI runner  
**Project Type**: Swift CLI with adapter/library targets and repository-local benchmark automation  
**Performance Goals**: Structured direct path resolution should avoid unnecessary search when a valid canonical path is fetch verified; fallback search is only used for recovery/ambiguity and remains bounded by existing search behavior  
**Constraints**: CLI-first product runtime; no MCP main path; fetch verification required for high confidence; `search`, `fetch`, and `list` output compatibility preserved; benchmark MCP assets remain isolated; no network-only tests in the default suite  
**Scale/Scope**: Resolver v1 covers Apple API documentation structured intents for `framework + symbol`, `framework + type`, and `framework + type + member`; Help/App Store Connect remain search/fetch only

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Offline-First**: PASS. Resolve verifies evidence through existing fetch, which already follows cache/local/remote order. Search fallback remains a recovery path, not the first structured path.
- **II. Stateless CLI/Adapter Design**: PASS. `idocs resolve` accepts the complete structured intent per invocation and requires no session state or prior command.
- **III. Test-First**: PASS. Tasks will add failing Swift tests for models, resolver behavior, adapter contract, and CLI output before implementation, plus Node tests for audit capability layering.
- **IV. Observability**: PASS. Resolve output and adapter models expose resolve diagnostics and fetch diagnostics separately.
- **V. Simplicity**: PASS. The new command is justified as P0 agent-facing evidence entry. The implementation avoids embeddings, NLP, services, databases, and MCP runtime.
- **VI. Native Swift First**: PASS. Product runtime changes stay in Swift and reuse existing native fetch/search tools. Node changes are limited to existing benchmark scripts.
- **VII. Type Safety**: PASS. Resolver intent/result, confidence, diagnostics, candidates, and evidence are typed Swift models.
- **VIII. Agent Memory Boundary**: PASS. Architecture rules remain in the constitution; infrastructure guidance in `AGENTS.md` only points to this plan and the P0 resolve boundary.

## Project Structure

### Documentation (this feature)

```text
specs/013-agent-resolve-entry/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── audit-capability-layering.md
│   ├── documentation-service-resolve.md
│   └── resolve-cli.md
├── checklists/
│   ├── prd.md
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/
├── iDocsAdapter/
│   ├── Adapters/
│   │   ├── DefaultDocumentationAdapter.swift
│   │   └── MockDocumentationAdapter.swift
│   ├── Models/
│   │   ├── CoreEntities.swift
│   │   └── DocumentationError.swift
│   └── Protocols/
│       └── DocumentationService.swift
├── iDocsApp/
│   └── Commands/
│       ├── CLIExecutor.swift
│       ├── CLIOutputModels.swift
│       └── iDocsCLI.swift
└── iDocsKit/
    └── Tools/
        ├── FetchDocTool.swift
        ├── ResolveDocsTool.swift
        └── SearchDocsTool.swift

Tests/
├── iDocsAdapterTests/
│   └── DocumentationServiceContractTests.swift
└── iDocsTests/
    ├── CLICommandTests.swift
    ├── ResolveDocsToolTests.swift
    └── TestSupport/
        └── MockPayloads.swift

scripts/
└── benchmark/
    ├── run-random-search-audit.mjs
    ├── search-quality-lib.mjs
    └── tests/
        ├── run-random-search-audit.test.mjs
        └── search-quality-lib.test.mjs
```

**Structure Decision**: Keep resolver product logic in Swift (`iDocsKit` + adapter + CLI). Keep audit capability layering in existing Node benchmark scripts because the Search Quality Race stack already owns random audit fixtures, classification, reports, and issue collection.

## Phase 0: Research

See [research.md](./research.md). Planning decisions are resolved without open clarification markers.

## Phase 1: Design & Contracts

See [data-model.md](./data-model.md), [contracts/resolve-cli.md](./contracts/resolve-cli.md), [contracts/documentation-service-resolve.md](./contracts/documentation-service-resolve.md), [contracts/audit-capability-layering.md](./contracts/audit-capability-layering.md), and [quickstart.md](./quickstart.md).

## Post-Design Constitution Check

- **Offline-First**: PASS. Direct path attempts call fetch, preserving existing evidence retrieval order. Search fallback is diagnostic recovery only.
- **Stateless CLI/Adapter Design**: PASS. Resolve intent is complete input and the adapter method has no stateful preconditions.
- **Test-First**: PASS. The task plan must include RED tests for invalid intent, fetch-gated confidence, CLI JSON, adapter contract, and audit issue filtering.
- **Observability**: PASS. Contracts define separate resolver and fetch diagnostic payloads.
- **Simplicity**: PASS. Resolver v1 only covers structured Apple API documentation and avoids NLP/embedding scope.
- **Native Swift First**: PASS. Product code remains Swift-native; benchmark changes remain in the existing Node script layer.
- **Type Safety**: PASS. Contracts map to Codable/Equatable Swift models and constrained confidence/capability values.
- **Agent Memory Boundary**: PASS. `AGENTS.md` is updated only with current plan reference and infrastructure guidance.

## Complexity Tracking

No constitution violations requiring exception.
