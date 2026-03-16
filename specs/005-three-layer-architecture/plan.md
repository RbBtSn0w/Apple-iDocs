# Implementation Plan: Three-Layer Architecture Refactoring

**Branch**: `005-three-layer-architecture` | **Date**: 2026-03-16 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/005-three-layer-architecture/spec.md`

## Summary
Refactor the project into a formal three-layer architecture (Common, Adapter, Application) to decouple core documentation logic from the entry points (CLI, future App). The Common layer remains reusable and testable; the Adapter provides a stable async API and compatibility checks; the Application layer is a thin orchestration and UX shell.

## Technical Context

**Language/Version**: Swift 6.x, Swift Concurrency (async/await)
**Build System**: Tuist
**Entry Points**: CLI now; native App later (macOS/iOS/iPadOS)
**Storage**: DiskCache / MemoryCache (cache paths injected per application environment)
**Testing**: Swift Testing
**Constraints**:
- Pure async/await (no completion handlers in Adapter)
- Common layer has no dependency on Application frameworks (e.g., ArgumentParser, SwiftUI)
- App sandbox compatibility (no global writable paths by default)
- Version compatibility enforced at runtime (Adapter <-> Common major version)
**Scope**: Reorganize targets and module boundaries; define Adapter contracts; migrate CLI to Adapter; ensure Gate criteria are automatable.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **Offline-First**: Does the design preserve the three-layer data fallback (Local -> Disk -> Remote)?
- [x] **Stateless Tool Design**: Does the Adapter preserve the stateless nature of documentation tools?
- [x] **Test-First**: Is there a plan for a `MockDocumentationAdapter` to enable isolated testing?
- [x] **Observability**: Does the design include a `Logger` protocol for cross-layer logging?
- [x] **Simplicity**: Does the three-layer split avoid over-engineering for the current CLI + Future App scope?
- [x] **Native Swift First**: Does the Adapter use Swift Concurrency (async/await) exclusively?
- [x] **Type Safety**: Are errors mapped to a domain-specific `DocumentationError` enum?
- [x] **Sandbox Safety**: Are cache paths and file writes explicitly injected for App environments?
- [x] **Version Safety**: Is there an explicit runtime version gate between Adapter and Common?

## Architecture Overview

### Layers and Responsibilities

- **Application Layer (CLI, App)**: UX, argument parsing, presentation strings, auth/session (if needed), and lifecycle.
- **Adapter Layer**: Stable async API for the app(s), error mapping, logging plumbing, configuration injection, and version gate.
- **Common Layer**: Core documentation capabilities (fetch, search, render, cache). No knowledge of CLI/App frameworks.

### Non-Goals (Phase 1)

- No requirement for CLI/App sharing the same cache directory by default (App sandbox isolation).
- No requirement to introduce file locking unless a shared cache is intentionally configured later.

## Project Structure

### Documentation (this feature)

```text
specs/005-three-layer-architecture/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
Sources/
├── iDocsKit/            # Common Layer (Core capabilities)
│   ├── Cache/           # Memory/Disk cache, cache keying
│   ├── DataSources/     # Apple APIs, local docs access
│   ├── Rendering/       # DocC types + renderer
│   ├── Tools/           # Use-cases: search/fetch/list (no CLI/App deps)
│   └── Utils/           # Config, Logger protocol, helpers
├── iDocsAdapter/        # Adapter Layer (protocols + concrete adapter)
│   ├── Protocols/       # DocumentationService, DocumentationLogger
│   ├── Models/          # DocumentationConfig, DocumentationError, results
│   └── Adapters/        # Real adapter, Mock/InMemory adapter(s)
└── iDocs/               # Application Layer (CLI)
    ├── Commands/        # ArgumentParser commands (AsyncParsableCommand)
    └── Main.swift       # Entry point injecting Adapter + Config + Logger

Tests/
├── iDocsKitTests/       # Unit tests for Common logic
├── iDocsAdapterTests/   # Tests for Adapter mapping/logic
└── iDocsTests/          # Integration tests using MockAdapter
```

**Structure Decision**: Prefer a dedicated Adapter target to enforce boundaries (Application can depend on Adapter; Adapter depends on Common; Common depends on neither). If Tuist graph complexity becomes a blocker, allow Adapter to live as a submodule within the Common package, but keep boundaries enforceable via Gate checks.

## Technical Design (Key Decisions)

### 1. Configuration Injection

- Define `DocumentationConfig` in the Adapter/Common boundary (see `data-model.md`).
- Application layer owns defaults and populates config per environment:
- CLI chooses a user-writable cache path (e.g., under `~/Library/Caches/` or `~/.cache/`).
- App uses sandboxed caches directory (via `FileManager`), optionally App Groups if explicit sharing is required later.

### 2. Logging Injection

- Common defines a minimal `DocumentationLogger` protocol.
- Adapter wires the injected logger into Common components.
- Application layer selects concrete implementation (stderr for CLI; OSLog/file for App).

### 3. Error Surface (DX + Rigor)

- Adapter defines `DocumentationError` with stable cases.
- Common internal errors map to `DocumentationError` (no leakage of URLSession/FS details unless wrapped as context).

### 4. Version Compatibility (Gate)

- Common exposes a `coreVersion` string (SemVer).
- Adapter checks `major` compatibility at startup and fails fast with a clear error message if incompatible.
- CLI/App surfaces this error as a user-actionable message (e.g., update CLI or framework).

### 5. Concurrency Model

- Adapter API is async-only.
- Common actors remain internal; shared mutable state isolated behind actors where necessary.
- Avoid relying on thread affinity; App UI updates stay in the Application layer.

### 6. Disk Cache Contention

- Default: no shared cache directory between CLI and App (App sandbox isolation).
- If a shared cache is explicitly configured (e.g., App Group directory), introduce file-based locking as an opt-in feature.

## Implementation Phases (Gate-Oriented)

### Phase 0: Inventory and Boundaries

- Identify all Common-layer files that currently import or depend on entry-point frameworks.
- Define the final target graph in Tuist (Common, Adapter, CLI).
- Add an automated dependency check for SC-005 / SC-006 (scripted in CI).

### Phase 1: Adapter Contracts and Core Versioning

- Finalize `DocumentationService`, models, and error types (see `contracts/` and `data-model.md`).
- Implement version handshake (`coreVersion` + Adapter major check).
- Implement `MockDocumentationAdapter` or `InMemoryAdapter` for CLI tests.

### Phase 2: Refactor CLI to Adapter

- Migrate CLI commands to call the Adapter only.
- Switch to `AsyncParsableCommand`.
- Ensure config/logger injection is the only way to affect runtime behavior.

### Phase 3: Common Layer Cleanup and Packaging

- Remove any stray imports of CLI/App frameworks from Common.
- Ensure Common can be built as framework/xcframework for App targets.
- Keep CLI linkage flexible (static or dynamic).

### Phase 4: Verification and Gates

- Enforce SC-005..SC-009 in CI (dependency, access, async-only, sandbox readiness, version gate).
- Run unit tests for Common and Adapter; run CLI tests using mock adapters.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | | |
