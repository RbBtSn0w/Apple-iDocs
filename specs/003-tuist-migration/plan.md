# Implementation Plan: Migrate project management to Tuist

**Branch**: `003-tuist-migration` | **Date**: 2026-03-16 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-tuist-migration/spec.md`

## Summary

Migrate the project management from a standard Swift Package Manager (SPM) setup to a Tuist-managed environment. This involves moving dependency declarations to `Tuist/Package.swift`, defining the project structure in `Project.swift`, and ensuring the project can be generated, built, and tested entirely via the Tuist CLI.

## Technical Context

**Language/Version**: Swift 6.2+  
**Primary Dependencies**: Tuist 4.x, MCP SDK (v0.11.0+), Swift Service Lifecycle (v2.3.0+), Swift Log  
**Storage**: N/A (Manifest-based)  
**Testing**: Swift Testing (unit tests in `iDocsTests`)  
**Target Platform**: macOS (13.0+)
**Project Type**: CLI / Executable (`iDocs`) + Unit Tests (`iDocsTests`)  
**Performance Goals**: Project generation < 10 seconds (SC-001)  
**Constraints**: Offline-first (Tuist caching), Native Swift First (Tuist manifests), Type Safety (Swift manifests)  
**Scale/Scope**: Full migration of existing `Package.swift` and `Project.swift` to Tuist 4+ standards.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Offline-First**: ✅ Tuist supports local project generation and binary caching, reducing reliance on remote fetching after initial install.
- **III. Test-First**: ✅ Plan includes verifying `tuist test` functionality and ensuring existing tests pass.
- **V. 极简主义**: ✅ Removing the redundant root `Package.swift` simplifies the project structure.
- **VI. Swift 原生优先**: ✅ Tuist uses Swift for all manifests, aligning with the project's native focus.
- **VII. 类型安全**: ✅ Manifests are compiled Swift code, providing compile-time safety for project configuration.

## Project Structure

### Documentation (this feature)

```text
specs/003-tuist-migration/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
# Tuist Managed Structure
Tuist/
├── Config.swift
└── Package.swift        # Centralized dependencies

Sources/
└── iDocs/               # Main executable logic

Tests/
└── iDocsTests/          # Unit tests

Project.swift            # Main project definition
Package.swift            # [TO BE REMOVED/STUBBED after migration]
```

**Structure Decision**: Single project (Option 1) with centralized Tuist manifests in the `Tuist/` directory.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
