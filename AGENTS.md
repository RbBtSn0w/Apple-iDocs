> **Note:** For project-specific architectural rules, design patterns, and coding standards, refer to `.specify/memory/constitution.md`.

# iDocs Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-05-18

## Active Technologies
- Swift 6.0 project settings plus Node.js ES modules for benchmark scripts + Tuist, swift-argument-parser, swift-log, Foundation, existing iDocsKit data sources/tools, Node.js built-in test runner (013-agent-resolve-entry)
- Existing disk cache for fetch; benchmark fixture JSON under `specs/008-mcp-service-benchmark/fixtures/`; no new persistent service storage (013-agent-resolve-entry)
- Swift 6.0 project settings + Tuist, Foundation, swift-argument-parser, swift-log, existing iDocsKit fetch/data-source/rendering stack (014-fix-docc-identifier)
- Existing fetch disk cache only; no cache format migration because encoded `DocCContent.identifier` remains a string (014-fix-docc-identifier)

- Swift 6.0（项目设置）+ shell scripts + Tuist, swift-argument-parser, swift-log；外部目标为 `idocs` CLI、`apple-docs-mcp`、`apple-doc-mcp`、`sosumi.ai` (008-mcp-service-benchmark)

## Project Structure

```text
Project.swift
Sources/
Tests/
Tuist/
└── Package.swift
```

## Commands

# Add commands for Swift 6.0（项目设置）+ shell scripts
- **Build**: `./scripts/tuist-silent.sh build iDocs` or `tuist build`
- **Test**: `./scripts/tuist-silent.sh test` or `tuist test iDocs --inspect-mode local --no-upload --no-selective-testing -- -destination 'platform=macOS,name=My Mac'`
- **Run Resolve Smoke**: `./scripts/tuist-silent.sh run idocs resolve --framework SwiftUI --symbol NavigationSplitView --json`
- **Generate Project**: `tuist generate --no-open`

## Code Style

Swift 6.0（项目设置）+ shell scripts: Follow standard conventions

## Infrastructure Guidelines
- **Project Generation**: This project uses Tuist (`Project.swift`, `Tuist.swift`) for project generation and management. Run `tuist generate --no-open` to generate Xcode workspace without launching Xcode IDE.
- **Dependency Management**: Tuist owns the project graph in `Project.swift`; Swift Package Manager is used only for third-party dependencies declared in `Tuist/Package.swift` and consumed through `.external(...)`.
- **SPM Boundary**: For App/CLI/main products, `Tuist/Package.swift` is a dependency entry point, not a repository identity manifest. Only SDK/library repositories that publish through SwiftPM should use a root `Package.swift`, because that manifest is their external release contract.
- **Headless Tests**: Tuist test runs should use the shared `iDocs` scheme with local inspect mode, `--no-upload`, `--no-selective-testing`, and an explicit macOS destination so they do not depend on opening Xcode, remote result inspection, or Tuist server state.
- **Git Commit Workflow**: Please follow Conventional Commits standard (e.g. `feat: ...`, `fix: ...`, `docs: ...`).
- **Agent-Facing Documentation Entry**: `idocs resolve` is the P0 agent-facing capability for structured Apple documentation evidence retrieval. Agents should prefer structured resolve intents for API evidence, use `idocs fetch` as the canonical evidence authority for known paths, and treat `idocs search` as exploration and candidate discovery rather than the primary correctness path.

## Recent Changes
- 014-fix-docc-identifier: Added Swift 6.0 project settings + Tuist, Foundation, swift-argument-parser, swift-log, existing iDocsKit fetch/data-source/rendering stack
- 013-agent-resolve-entry: Added Swift 6.0 project settings plus Node.js ES modules for benchmark scripts + Tuist, swift-argument-parser, swift-log, Foundation, existing iDocsKit data sources/tools, Node.js built-in test runner

- 008-mcp-service-benchmark: Added Swift 6.0（项目设置）+ shell scripts + Tuist, swift-argument-parser, swift-log；外部目标为 `idocs` CLI、`apple-docs-mcp`、`apple-doc-mcp`、`sosumi.ai`

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan:
specs/014-fix-docc-identifier/plan.md
<!-- SPECKIT END -->
