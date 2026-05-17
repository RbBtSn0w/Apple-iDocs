# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: [e.g., Python 3.11, Swift 5.9, Rust 1.75 or NEEDS CLARIFICATION]  
**Primary Dependencies**: [e.g., FastAPI, UIKit, LLVM or NEEDS CLARIFICATION]  
**Storage**: [if applicable, e.g., PostgreSQL, CoreData, files or N/A]  
**Testing**: [e.g., pytest, XCTest, cargo test or NEEDS CLARIFICATION]  
**Target Platform**: [e.g., Linux server, iOS 15+, WASM or NEEDS CLARIFICATION]
**Project Type**: [e.g., library/cli/web-service/mobile-app/compiler/desktop-app or NEEDS CLARIFICATION]  
**Performance Goals**: [domain-specific, e.g., 1000 req/s, 10k lines/sec, 60 fps or NEEDS CLARIFICATION]  
**Constraints**: [domain-specific, e.g., <200ms p95, <100MB memory, offline-capable or NEEDS CLARIFICATION]  
**Scale/Scope**: [domain-specific, e.g., 10k users, 1M LOC, 50 screens or NEEDS CLARIFICATION]

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The plan MUST explicitly answer each iDocs constitution gate:

- **Offline-first chain**: Does the design preserve deterministic local/cache-first behavior before remote Apple and sosumi fallbacks?
- **Stateless CLI/Adapter boundary**: Do CLI commands and `DocumentationService` APIs carry complete inputs and avoid session state or MCP runtime coupling?
- **Agent Evidence Entry**: If Apple API evidence is involved, does the design route structured agent intents through `idocs resolve`, use `idocs fetch` as the canonical evidence authority, and keep `idocs search` as exploration/candidate discovery?
- **TDD evidence**: Are RED tests planned before implementation for changed CLI, adapter, iDocsKit, diagnostics, and benchmark behavior?
- **Observability**: Are source markers and distinct `resolve_diagnostics`, `fetch_diagnostics`, or `search_diagnostics` preserved where relevant?
- **Simplicity**: Is any new command, data source, service, or benchmark complexity justified against the current `resolve` / `fetch` / `search` / `list` command surface?
- **Native Swift first**: Does production runtime stay Swift/macOS native without introducing Node, Python, web servers, or MCP SDKs into the shipped CLI path?
- **Type safety**: Are public payloads and errors modeled with explicit Swift types and constrained state values instead of untyped dictionaries or erased values?
- **Agent memory boundary**: Are architecture rules kept in the constitution and operational commands kept in AGENTS/runtime docs?

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
Sources/
├── iDocsCLI/       # Thin executable entry point
├── iDocsApp/       # ArgumentParser commands, CLIExecutor, payloads
├── iDocsAdapter/   # DocumentationService boundary, public models, adapters
└── iDocsKit/       # Core tools, data sources, renderer, cache

Tests/
├── iDocsTests/
└── iDocsAdapterTests/

scripts/benchmark/ # Capability-layered quality audit and issue tooling

specs/
└── [###-feature]/
```

**Structure Decision**: [Document the selected structure and reference the real
directories captured above]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
