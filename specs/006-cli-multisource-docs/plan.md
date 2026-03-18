# Implementation Plan: iDocs CLI Capability Unification and Multi-Source Retrieval

**Branch**: `006-cli-multisource-docs` | **Date**: 2026-03-18 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/006-cli-multisource-docs/spec.md`

## Summary

Unify the CLI capability contract around `idocs`, complete the local Xcode retrieval path (search + fetch), and introduce deterministic remote fallback from Apple to sosumi for `search` and `fetch`. Add source-hit observability and anti-regression gates to keep implementation, contracts, and docs aligned.

## Technical Context

**Language/Version**: Swift 6.0 (project setting), async/await concurrency  
**Primary Dependencies**: swift-argument-parser, swift-log  
**Storage**: In-memory cache + disk cache files + local Xcode documentation cache  
**Testing**: Swift Testing via `tuist test` / `tuist xcodebuild test`  
**Target Platform**: macOS 13+  
**Project Type**: CLI application with layered architecture (`iDocsKit` + `iDocsAdapter` + `iDocs`)  
**Performance Goals**: Local-first retrieval for low-latency search/fetch; fallback should remain bounded and deterministic  
**Constraints**: CLI-only scope; stable error/exit semantics; no MCP runtime restoration  
**Scale/Scope**: Affect `search`/`fetch` retrieval chain, source observability, docs/contracts, and gate coverage

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. 离线优先**: PASS. Plan explicitly implements cache/local-first retrieval before remote.
- **II. 无状态工具设计**: PASS. CLI operations remain request-local and stateless.
- **III. 测试先行**: PASS. Add/adjust tests before behavior changes in chain and fallback.
- **IV. 可观测性**: PASS. Source-hit visibility and failure-path diagnostics are included.
- **V. 极简主义**: PASS. Scope limited to `search`/`fetch` and contract/gate hardening.
- **VI. Swift 原生优先**: PASS. Uses existing Swift-native stack and local filesystem/Xcode sources.
- **VII. 类型安全**: PASS. Extend models/contracts with typed source metadata instead of ad-hoc text parsing.

Post-design re-check: PASS (no additional violations introduced by research/design decisions).

## Project Structure

### Documentation (this feature)

```text
specs/006-cli-multisource-docs/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── cli-interface.md
│   └── source-policy.md
└── tasks.md
```

### Source Code (repository root)

```text
Sources/
├── iDocs/
│   ├── Commands/
│   ├── DataSources/
│   ├── Tools/
│   └── Utils/
├── iDocsAdapter/
│   ├── Adapters/
│   ├── Models/
│   └── Protocols/
└── iDocsKit/
    └── Utils/

Tests/
├── iDocsTests/
│   ├── IntegrationTests/
│   ├── Mocks/
│   └── TestSupport/
└── iDocsAdapterTests/

scripts/
└── arch-gate.sh
```

**Structure Decision**: Reuse the existing single-repo layered structure and implement feature changes in retrieval/data-source, adapter mapping, CLI presentation, tests, and gate scripts.

## Complexity Tracking

No constitution violations requiring exception.
