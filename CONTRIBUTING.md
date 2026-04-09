# Contributing to iDocs

Thanks for your interest in contributing.

## Development Setup

1. Install dependencies:
   - macOS 13+
   - Xcode 15+
   - Tuist
2. Install and generate project:
   ```bash
   tuist install
   tuist generate
   ```
3. Build and test:
   ```bash
   tuist build iDocs
   ./scripts/tuist-silent.sh test
   ```

## Contribution Workflow

1. Fork the repository and create a feature branch from `main`.
2. Follow TDD when possible: write failing tests first, then implement.
3. Keep changes focused and include/adjust tests for behavioral changes.
4. Run quality checks before opening a PR:
   ```bash
   ./scripts/arch-gate.sh
   ./scripts/spec-trace-gate.sh
   ./scripts/coverage-gate.sh 60
   ./scripts/e2e-cli.sh
   ```
5. Open a PR with:
   - clear problem statement
   - implementation summary
   - verification evidence (commands + key outputs)

## Commit Message Convention

Use Conventional Commits, for example:

- `feat: add local docs fallback for search`
- `fix: resolve cache ttl parsing bug`
- `docs: update npm release workflow`

## Code of Conduct

By participating, you agree to follow [Code of Conduct](./CODE_OF_CONDUCT.md).
