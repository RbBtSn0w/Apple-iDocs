# Implementation Plan: search-fallback-diagnostics

**Branch**: `009-search-fallback-diagnostics` | **Date**: 2026-05-09 | **Spec**: `specs/009-search-fallback-diagnostics/spec.md`
**Input**: Feature specification from `/specs/009-search-fallback-diagnostics/spec.md`

## Summary

Fix `idocs search` when the local Xcode DocumentationCache is unavailable by preserving the CLI-first fallback chain, improving exact remote Apple routing for common API/HIG terms, and surfacing structured diagnostics that distinguish cache misses, true remote misses, and network or permission failures.

## Technical Context

**Language/Version**: Swift 6.0
**Primary Dependencies**: Tuist, Swift Package Manager for third-party dependencies, swift-argument-parser, swift-log
**Storage**: Local Xcode DocumentationCache, memory cache, disk cache, remote Apple Developer and sosumi lookups
**Testing**: Swift Testing through Tuist-generated Xcode test targets
**Target Platform**: macOS
**Project Type**: CLI application
**Performance Goals**: Preserve fast local search; make fallback stage latency observable
**Constraints**: CLI-first, no GUI or browser side effects, stateless per invocation, official Apple documentation URLs for routed results

## Constitution Check

- **Offline-first**: Pass. Local cache remains the first live documentation source, and cache absence is reported as a diagnostic rather than treated as a fatal error.
- **Stateless CLI/Adapter Design**: Pass. Diagnostics are returned with each search response and do not require daemon state.
- **Observability**: Pass. Search stages now expose status, duration, result count, reason, and actionable hint.
- **Native Swift First**: Pass. Existing Swift `URLSession` search clients remain the remote implementation.
- **Type Safety**: Pass. Diagnostics use explicit Swift models in the adapter contract.

## Project Structure

### Documentation

```text
specs/009-search-fallback-diagnostics/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── tasks.md
├── quickstart.md
├── acceptance-traceability.md
└── checklists/
```

### Source Code

```text
Sources/
├── iDocsApp/
│   └── Commands/
├── iDocsAdapter/
│   ├── Adapters/
│   ├── Models/
│   └── Protocols/
├── iDocsCLI/
│   └── Main.swift
└── iDocsKit/
    ├── Cache/
    ├── DataSources/
    ├── Rendering/
    ├── Tools/
    └── Utils/

Tests/
├── iDocsTests/
└── iDocsAdapterTests/
```

## Implementation Strategy

1. Extend the adapter search contract with optional structured diagnostics while preserving the existing `[SearchResult]` API.
2. Record every search stage in `SearchDocsTool`, including local cache status, Apple fallback status, sosumi fallback status, and actionable reason/hint data.
3. Add exact-route recovery in `AppleJSONAPI` for known API/HIG terms that remote indexed search misses.
4. Surface diagnostics through CLI text and JSON output without changing the CLI command shape.
5. Keep Tuist as the App/CLI project graph and build/test entry point while `Tuist/Package.swift` only declares third-party SwiftPM dependencies consumed through `.external(...)`; reserve root `Package.swift` for SDK repositories that publish a SwiftPM contract.

## Verification

Primary commands:

```bash
tuist install
tuist build
tuist test iDocs --inspect-mode local --no-upload --no-selective-testing -- -destination 'platform=macOS,name=My Mac'
./scripts/arch-gate.sh
```

Focused checks:

```bash
tuist test iDocs --inspect-mode local --no-upload --no-selective-testing --test-targets iDocsTests -- -destination 'platform=macOS,name=My Mac'
tuist test iDocs --inspect-mode local --no-upload --no-selective-testing --test-targets iDocsAdapterTests -- -destination 'platform=macOS,name=My Mac'
idocs search --json "NavigationSplitView"
idocs search --json "inspectorColumnWidth"
idocs search --json "SomeFakeAPIThatDoesntExistInApple"
```
