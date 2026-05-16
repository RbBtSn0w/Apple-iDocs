# Implementation Plan: Search Quality Race CI

**Branch**: `012-search-quality-race` | **Date**: Saturday, May 16, 2026 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `specs/012-search-quality-race/spec.md`

## Summary

Add a remote-only scheduled and manual search-quality race that builds the current `idocs` CLI, evaluates it and public npm competitor releases against one seeded stratified random audit sample, publishes GitHub run summaries and retained artifacts, and creates or updates repository issues only for actionable iDocs golden-truth failures. The implementation stays in the existing CLI plus benchmark tooling boundary: Swift owns iDocs configuration and diagnostics, Node.js benchmark scripts own competitor installation, sampling, classification, report rendering, and issue collection, and GitHub Actions orchestrates the nightly/manual workflow.

## Technical Context

**Language/Version**: Swift 6.0 project settings + Node.js ES modules for benchmark orchestration + GitHub Actions YAML  
**Primary Dependencies**: Tuist, swift-argument-parser, swift-log, Foundation; Node.js built-ins; `gh` CLI in CI for issue collection; public npm competitor packages  
**Storage**: Audit fixtures under `specs/008-mcp-service-benchmark/fixtures/`; run outputs under CI workspace artifact paths; no persistent application storage changes  
**Testing**: Swift Testing through `./scripts/tuist-silent.sh test`; Node script smoke/unit tests through Node's built-in test runner; workflow validation through manual GitHub Actions dispatch  
**Target Platform**: macOS CI runner and local macOS development shell  
**Project Type**: Swift CLI repository with benchmark automation and CI workflow  
**Performance Goals**: Default sample size 40 completes within a nightly CI budget; runner scripts fail fast on infrastructure errors while preserving per-case quality verdicts  
**Constraints**: CLI-only iDocs runtime; no MCP/server transport in product runtime; local Xcode documentation cache excluded from race; quality failures do not fail CI; infrastructure failures do fail CI; no raw secrets in reports, artifacts, issues, or comments  
**Scale/Scope**: 4 products by default (`idocs` plus three npm competitors), initial pool covering 6 product/framework areas and 6 query shapes, one nightly workflow plus manual dispatch inputs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Offline-First**: PASS. The production CLI remains cache/local-first for normal use. The race intentionally configures CI as remote-only and reports that degradation instead of changing the default local-first contract.
- **II. Stateless CLI/Adapter Design**: PASS. `idocs search` remains stateless and complete per invocation. Benchmark scripts pass explicit inputs and do not add session state to the product runtime.
- **III. Test-First**: PASS. Tasks will add Node tests and Swift tests before implementation changes, including sampler determinism, classification, fingerprinting, issue dry-run behavior, and local-cache override diagnostics.
- **IV. Observability**: PASS. Reports and artifacts include seed, sample, versions, diagnostics, classifications, verdicts, raw evidence references, and reproduction commands.
- **V. Simplicity**: PASS. The benchmark remains a repository-local CI/script system. It does not become a generic service, MCP runtime, database-backed dashboard, or PR merge gate.
- **VI. Native Swift First**: PASS. Swift changes are limited to typed iDocs configuration and CLI diagnostics. Benchmark orchestration uses Node because the requested competitor surface is npm-release based and already lives under `scripts/benchmark`.
- **VII. Type Safety**: PASS. Swift configuration remains strongly typed. Node runner schemas are documented in contracts and verified by script tests.
- **VIII. Agent Memory Boundary**: PASS. Architecture and design details stay in Spec Kit artifacts; `AGENTS.md` is updated only to point to this plan as the current feature context.

## Project Structure

### Documentation (this feature)

```text
specs/012-search-quality-race/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── audit-record.md
│   ├── issue-collection.md
│   └── workflow.md
├── checklists/
│   ├── alignment.md
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
.github/
└── workflows/
    └── search-quality-race.yml

Sources/
├── iDocsAdapter/
│   └── Models/
│       └── DocumentationConfig.swift
├── iDocsApp/
│   └── Commands/
│       ├── CLIEnvironment.swift
│       ├── CLIExecutor.swift
│       └── CLIOutputModels.swift
└── iDocsKit/
    └── DataSources/
        └── XcodeLocalDocs.swift

Tests/
├── iDocsTests/
│   ├── CLICommandTests.swift
│   └── XcodeLocalDocsMockTests.swift
└── BenchmarkScriptTests/
    └── search-quality-race.test.mjs

scripts/
└── benchmark/
    ├── install-corrival-releases.mjs
    ├── run-random-search-audit.mjs
    ├── render-search-quality-summary.mjs
    ├── create-search-quality-issue.mjs
    ├── search-quality-lib.mjs
    └── fixtures/
        └── mock-target-results.json

specs/
└── 008-mcp-service-benchmark/
    └── fixtures/
        └── search-audit-pool.json
```

**Structure Decision**: Keep iDocs runtime changes inside existing Swift modules and place race orchestration in `scripts/benchmark`, matching the current benchmark tooling boundary. The audit pool remains under the existing 008 benchmark fixtures because it is shared benchmark data, while 012 owns the CI automation, random sampling, reporting, issue collection, and remote-only control requirements.

## Phase 0: Research

See [research.md](./research.md). Planning decisions are resolved without open clarification markers.

## Phase 1: Design & Contracts

See [data-model.md](./data-model.md), [contracts/workflow.md](./contracts/workflow.md), [contracts/audit-record.md](./contracts/audit-record.md), [contracts/issue-collection.md](./contracts/issue-collection.md), and [quickstart.md](./quickstart.md).

## Post-Design Constitution Check

- **Offline-First**: PASS. Remote-only behavior is opt-in through CI/runtime configuration and explicitly reported; normal CLI defaults remain local-first.
- **Stateless CLI/Adapter Design**: PASS. Scripts call stateless CLI commands with full query inputs and per-run environment variables.
- **Test-First**: PASS. Design maps every behavioral requirement to Swift or Node tests before implementation tasks.
- **Observability**: PASS. Artifact contracts include exact versions, run metadata, diagnostics, classification, verdict, raw evidence, summary tables, and issue fingerprints.
- **Simplicity**: PASS. No database, long-running service, or product runtime transport is introduced.
- **Native Swift First**: PASS. Product configuration remains Swift-native; npm-specific orchestration stays in repository scripts.
- **Type Safety**: PASS. Swift changes use typed config fields and JSON payload models; Node contracts define constrained enums and required fields.
- **Agent Memory Boundary**: PASS. `AGENTS.md` only points to this plan; detailed rules are held in Spec Kit artifacts.

## Complexity Tracking

No constitution violations requiring exception.
