# Implementation Plan: CLI Version Support

**Branch**: `010-fix-cli-version` | **Date**: Sunday, May 10, 2026 | **Spec**: [specs/010-fix-cli-version/spec.md](spec.md)
**Input**: Feature specification from `specs/010-fix-cli-version/spec.md`

## Summary

Add `--version` support to the `idocs` CLI by explicitly setting the `version` parameter in the `ArgumentParser`'s `CommandConfiguration` for `iDocsCLI`. This effectively decouples the CLI version from the internal `coreVersion` and ensures native support for both `-v` and `--version` flags. The npm `package.json` version will also be bumped to 1.3.1 to match.

## Technical Context

**Language/Version**: Swift 6.0
**Primary Dependencies**: `swift-argument-parser`
**Storage**: N/A
**Testing**: Swift Testing (via `iDocsTests`)
**Target Platform**: macOS 13.0+
**Project Type**: CLI
**Performance Goals**: < 100ms output for `--version`
**Constraints**: Decouple from `coreVersion`
**Scale/Scope**: Small isolated CLI parameter update

## Constitution Check

*GATE: Passed*
- **II. Stateless CLI/Adapter Design**: Does not add state or affect current command lifecycle.
- **V. Simplicity**: Uses existing `ArgumentParser` feature.
- **VI. Native Swift First**: Uses `swift-argument-parser` over npm wrapping.

## Project Structure

### Documentation (this feature)

```text
specs/010-fix-cli-version/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
Sources/iDocs/Commands/
└── iDocsCLI.swift       # Configuration update

npm/
└── package.json         # Version bump
```

## Complexity Tracking

No violations.
