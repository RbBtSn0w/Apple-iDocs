> **Note:** For project-specific architectural rules, design patterns, and coding standards, refer to `.specify/memory/constitution.md`.

# iDocs-mcp Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-03-19

## Active Technologies

- Swift 6.0（项目设置）+ shell scripts + Tuist, swift-argument-parser, swift-log；外部目标为 `idocs` CLI、`apple-docs-mcp`、`apple-doc-mcp`、`sosumi.ai` (008-mcp-service-benchmark)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for Swift 6.0（项目设置）+ shell scripts
- **Build**: `tuist build` or `swift build`
- **Test**: `tuist test` or `swift test`
- **Generate Project**: `tuist generate`

## Code Style

Swift 6.0（项目设置）+ shell scripts: Follow standard conventions

## Infrastructure Guidelines
- **Project Generation**: This project uses Tuist (`Project.swift`, `Tuist.swift`) for project generation and management. Run `tuist generate` to generate Xcode workspace.
- **Dependency Management**: Swift Package Manager (SPM).
- **Git Commit Workflow**: Please follow Conventional Commits standard (e.g. `feat: ...`, `fix: ...`, `docs: ...`).

## Recent Changes

- 008-mcp-service-benchmark: Added Swift 6.0（项目设置）+ shell scripts + Tuist, swift-argument-parser, swift-log；外部目标为 `idocs` CLI、`apple-docs-mcp`、`apple-doc-mcp`、`sosumi.ai`

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
