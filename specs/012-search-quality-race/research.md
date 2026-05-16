# Research: Search Quality Race CI

## Decision 1: Evaluate competitors from public npm releases

**Decision**: Install competitor packages from npm during each CI run and record the exact resolved version for every package.

**Rationale**: The requested comparison is against public releases, not upstream source repositories. Recording exact versions makes results reproducible and avoids silently comparing against local checkout drift.

**Alternatives considered**:
- Clone upstream repositories: rejected because it changes the benchmark target from published consumer behavior to source checkout behavior.
- Use vendored `corrival/` directories: rejected for CI as a default because it can drift from public release state.

## Decision 2: Keep quality failures separate from infrastructure failures

**Decision**: Treat iDocs golden-truth mismatches as quality findings that are reported and issue-collected, while build, package installation, runner crashes, report generation, artifact publication, and required issue collection failures fail the workflow.

**Rationale**: The race is monitoring. A red workflow should indicate the monitoring machinery is broken, not that search quality produced a tracked finding.

**Alternatives considered**:
- Fail CI on any iDocs miss: rejected because nightly monitoring would become noisy and block unrelated work.
- Never fail CI: rejected because broken reports or missing artifacts would hide loss of monitoring coverage.

## Decision 3: Use remote-only CI by overriding local Xcode documentation path

**Decision**: Add an iDocs configuration override for the local Xcode documentation cache path and point CI to a nonexistent temporary path.

**Rationale**: CI runners do not provide a stable local Xcode DocumentationCache comparison surface. A deliberate unavailable path makes remote-only behavior explicit and testable, while preserving normal local-first defaults outside this workflow.

**Alternatives considered**:
- Delete or move runner cache directories: rejected as brittle and potentially destructive.
- Disable local docs with a boolean only: rejected because an explicit path override is easier to reproduce locally and test with mock paths.

## Decision 4: Centralize sampling, classification, rendering, and issue logic in a shared Node module

**Decision**: Put reusable audit logic in a shared ES module consumed by runner, renderer, issue collector, and Node tests.

**Rationale**: The same classification and fingerprint rules must drive reports, artifacts, and issue collection. Centralizing logic prevents summary/issue drift.

**Alternatives considered**:
- Duplicate small helpers in each script: rejected because verdict and fingerprint drift would be likely.
- Reimplement orchestration in Swift: rejected because npm competitor installation and script-level CI integration are already Node-centric.

## Decision 5: Keep GitHub issue creation idempotent by fingerprint

**Decision**: Compute the fingerprint from sorted iDocs failing case IDs, expected outcomes, and iDocs classifications. Search open issues for the fingerprint before creating a new issue.

**Rationale**: The actionable unit is the current set of iDocs golden-truth failures. Sorting makes the fingerprint stable across case execution order.

**Alternatives considered**:
- One issue per case: rejected because random samples can produce noisy issue churn.
- One issue per run: rejected because repeated failures would create duplicates.

## Decision 6: Use dry-run issue collection for local and CI validation

**Decision**: Support a no-mutation print/dry-run path for issue body generation and a simulated-failure mode for workflow validation.

**Rationale**: Issue body content and de-duplication paths need test coverage without requiring a real search regression or mutating GitHub during local tests.

**Alternatives considered**:
- Only test issue creation in live CI: rejected because it is slow, stateful, and hard to reproduce.
- Mock the whole script without rendering a real body: rejected because it would not validate the user-facing issue contract.
