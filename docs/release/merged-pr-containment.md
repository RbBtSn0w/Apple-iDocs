# Merged PR Containment Guardrail

This guardrail protects against a class of release/merge process failures where a
PR is merged and reported as "done" on GitHub, yet its commit never reaches the
branch that releases are cut from. It is implemented by
[`scripts/audit-merged-pr-containment.sh`](../../scripts/audit-merged-pr-containment.sh)
and run by the [`Merged PR Containment`](../../.github/workflows/merged-pr-containment.yml)
workflow on every push to `main`, on a daily schedule, and on demand.

## The incident this guards against

The DocC ingestion feature was merged, silently absent from a tagged release, and
then restored by a conflict-laden merge:

| Step | Commit | What happened |
| --- | --- | --- |
| Feature merged | `c42cce2` (PR #17, "add resilient DocC ingestion") | Merged into base branch **`014-fix-docc-identifier`**, not `main`, at 2026-05-19 01:25 UTC. Added `Sources/iDocsKit/Rendering/AppleDocCIngestion.swift` (621 lines). |
| Release cut | `fd6ce33` (v1.7.3) | Cut at 2026-05-19 01:29 UTC from parent `ee9f442` (PR #16). `git ls-tree fd6ce33` confirms the ingestion file was **absent**. |
| Feature restored | `0c4324c` (PR #18) | Restored the file into `main` via a merge that listed `.specify/feature.json`, `AGENTS.md`, and two test files as conflicts. |

**Root cause is branching/release topology, not the code.** PR #17 targeted a
feature branch rather than `main`, and the v1.7.3 release was cut from a `main`
commit (`ee9f442`) that did not yet contain the feature. The release automation
raced ahead of the path that was supposed to carry the feature into `main`.

## What the guardrail asserts

For each recently merged PR (up to `PR_LIMIT`, default 50), the audit checks that
the PR's recorded merge commit is an ancestor of `BASE_BRANCH` (default `main`).

- If any merged PR commit is **not** contained, the script emits a
  `::error` annotation per offender and **exits non-zero**, failing the workflow
  (it does not merely log). This is the behavior verified by
  [`scripts/tests/audit-merged-pr-containment.test.sh`](../../scripts/tests/audit-merged-pr-containment.test.sh).
- If everything is contained, it prints a confirmation and exits zero.

## Known exceptions (`EXCLUDE_PRS`)

The audit previously used a hard-coded `MERGED_AFTER` date floor to silence
historical noise. That floor was opaque and also blinded the audit to any genuine
pre-floor regression. It is replaced by an explicit, auditable exception list.

| PR | Reason it is excluded |
| --- | --- |
| #4 (`[codex] Fix idocs list telemetry contract`) | The recorded merge SHA `1004b89` was orphaned by a later history rewrite and is unreachable from `main`. The change itself **did** land on `main` as `450cf0d` ("feat: Fix idocs list telemetry contract (#4)"). Only the GitHub-recorded merge SHA diverged; no content was lost. |

Set exceptions via the `EXCLUDE_PRS` env var (comma- or space-separated PR
numbers). Excluded PRs are reported as `::notice` annotations so they stay
visible in the workflow log instead of vanishing behind a date cutoff.

Prefer adding a documented exception here over reintroducing a date floor: the
audit then keeps covering the full recent history and only consciously-approved
divergences are skipped.
