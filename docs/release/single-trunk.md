# Single-trunk scheduled publication

## Development and cadence

`main` is the only integration trunk. Short-lived feature/fix PRs target main and use reviewed Conventional Commit squash messages, including breaking-change footers. Retain branch cleanup. Remote develop may remain inactive; retirement needs separate authorization. This migration starts at main `69649730d68dcf24cfbda8d6ff79fd6682532f55` (the published `v1.10.0`); develop has no outstanding business delta. Existing dependency PR #58 stays independent.

Friday 15:00 Asia/Singapore/Asia/Shanghai is `0 7 * * 5` UTC. The same `release.yml` supports immediate `workflow_dispatch` on main after validated code merges. Ordinary push/PR CI never publishes. Schedule delivery can be delayed; a manual invocation does not bypass checks or select a version. Analysis and needed exact-candidate verification run without activation. All publication is default-off unless repository variable `RELEASE_ENABLED` equals `true`. A proven no-change plan skips native/product builds.

## Candidate, version and payload

The read-only job checks out the exact event SHA with full history/tags and runs product tests. A thin upstream semantic-release JS API dry-run executes in an isolated temporary local mirror, with real tags/notes and no service credentials. Both phases share `scripts/release/config.mjs`; no independent tag/version algorithm exists. Analysis must actually execute before false means no releasable changes. PR title/body retains strict commitlint. The actual engine-selected historical range validates parseable Conventional Commit release semantics, including breaking footers, without imposing PR style rules retroactively. Genuine multi-parent merge metadata is accepted; malformed ordinary or fake merge commits fail, including skip-marker commits. The published baseline remains mandatory.

Only when a release is needed, the read-only job builds the final native archive with the engine's version in `idocs.version`, creates the versioned npm wrapper, and runs publint and the actual wrapper installer/CLI against that same local archive through a temporary HTTP server. It seals the plan, both archives and native checksum. Publisher handoff uses this run's immutable artifact ID plus candidate SHA and per-file SHA-256 checks, not artifact-name lookup.

The release job installs only tooling with scripts disabled. It rereads live main, stops on read failure/drift, reanalyzes using semantic-release, and compares candidate, previous release, next version/tag/channel and configuration digest. No source build, lifecycle hook or version/changelog commit occurs under publication authority. If the second analysis produces no-op, that is a stale/already-released candidate requiring inspection, not this run's success.

semantic-release creates the tag and GitHub Release, attaching the already checked native archive and wrapper. The registry step downloads and checks the GitHub native asset before publishing the exact same wrapper tarball to npmjs and GitHub Packages. An existing version is accepted only with matching integrity. Homebrew follows both verified registry publications, using the release version and exact source checkout. The release line shares `release-main` concurrency with active runs never cancelled.

## Cutover prerequisites

Source changes and local checks establish **Staged**, not live publication. Before separately authorized merge/activation:

1. Inventory and settle active legacy releases and independent writers. The migration removes push publishing, develop promotion, reverse sync and manual source-directory npm publishers. It does not disable an external timer or alter existing cloud/registry settings.
2. Verify the published v1.10.0 baseline remains reachable and lint the actual accepted release range. Unexpected first-release behavior blocks activation. Confirm tag-write authority and actual checks/review enforcement; earlier classic protection probes returned 404 and rulesets were empty, not proof of enforcement.
3. Configure/verify npm trusted publishing for this repository and **release.yml**, compatible npm/Node, and any chosen environment. The former NPM_TOKEN path had no confirmed secret; this workflow uses explicit npm OIDC, never silent token fallback. Verify GitHub Packages packages:write and the tap App installation. Source migration does not change credentials.
4. After merge to the default branch, retest PR #58 against main and enable only `RELEASE_ENABLED`. Do not enable a second publisher or delete develop implicitly.
5. Observe the first authorized normal release: candidate, schedule/manual delivery, tag, assets, both registry integrities and tap update separately. A green local build proves none of the remote targets.

## Partial publication and recovery

Tags, GitHub assets, npmjs, GitHub Packages and Homebrew are independent side effects. Publication receipts are retained even on failure. Inspect all targets before retrying: do not delete tags, choose another version, regenerate an archive, or blindly rerun semantic-release after a tag exists.

Dispatch **Scheduled Release** on main with `operation=recover` and the original
normal `source_run_id` / immutable `artifact_id`. Trusted current-main tools bind
the actual same-repository/same-workflow completed main schedule/manual run,
artifact ownership, sealed plan/checksums and existing tag's peeled candidate SHA.
The original run may have failed. Continue to use that original source pair for
later retries, never a recovery run. Main advancing does not invalidate sealed
original bytes. Expired artifacts or missing/different tags fail closed.

Recovery never selects a version, builds native code or wrapper, creates a tag,
or overwrites an asset. Missing-release creation and matching-draft completion
explicitly avoid changing GitHub latest; sealed notes are used for a missing
release and existing release notes are preserved. It reuses matching GitHub releases/assets, repairs only
missing sealed assets, completes a matching draft, then reconciles npmjs and
GitHub Packages integrity independently. Only after both registries are verified
does the tap update run. Recovery publishes missing wrapper bytes under an
original-candidate recovery tag, verifies integrity, then explicitly reconciles
`latest`: retain a newer stable version, verify an equal version, or promote an
older/missing channel to the verified original version and read it back. It
removes only its own recovery tag after confirming its ownership. Unknown/read
failures stop channel changes and leave an incomplete target result. Normal
publication refuses to downgrade a newer registry channel. The tap likewise
retains a newer formula and rejects a same-version native checksum conflict.
The shared release lock serializes these workflows; it does not establish an
atomic guarantee against independent external registry or tap writers.

The dependency remains native archive -> wrapper ->
GitHub assets -> both registries -> tap. No native build occurs with credentials.

`release-result.json` and the Actions summary record verification and publication
separately, with independent GitHub/npm/GitHub Packages/tap results. Target
readbacks and receipts survive later target failure. Local verification is not
runtime activation or production delivery acceptance.

The `Release` workflow identifies scheduled, manual and original-recovery runs.
Its v2 outcome starts with the result and next action, followed by channel evidence
and collapsed technical details. Successful jobs without matching remote receipts
remain unconfirmed. First-failure recovery includes the original sealed producer
ID, digest, attempt and expiry only after the original tag is verified. Missing or
conflicting evidence blocks recovery rather than rebuilding the release.

Consumer-common code is generated under `.github/release-train/`; configuration
is `.github/release-train.json`. Product/native packaging and dual-registry/tap
adapters remain in this repository. Do not hand-edit generated modules. CI runs
`node .github/release-train/sync.mjs check --consumer .` entirely locally. An
authorized maintainer updates the generated directory using the owning Skill's
`scripts/release-train/sync.mjs sync --consumer <checkout> --revision <source-sha>`;
the manifest records the selected source and every file digest. Unknown or modified
generated files stop synchronization before replacement.

Use a new workflow dispatch to analyze current main. Re-running all jobs stops
before analysis, since an earlier attempt may already have created a tag. Re-running
only failed jobs preserves the successful producer's immutable IDs. A partial
publication is repaired through the original recovery identity printed in its
outcome; the static Actions form does not prefill or execute that command.

The npm registry Settings binding remains unobserved: current `ci.yml` versus
`release.yml` trust must be checked in Settings before activation; source evidence
alone does not establish a defect. Recovery channel reconciliation additionally requires the trusted publisher's independent **Allow npm dist-tag** permission (default off); npm 12.2.2 meets the documented CLI requirement. Its current permission state is unverified. See [npm trusted publishing](https://docs.npmjs.com/trusted-publishers/#managing-dist-tags-with-trusted-publishing). GitHub Packages read probing returned 403,
which does not prove absence or successful delivery. Release App ID `2758804`
and `RELEASE_BOT_PRIVATE_KEY` metadata exist; tap installation is unverified.
These are external readiness checks, not local code blockers. No remote setting,
credential, dispatch, tag or publication was changed by this implementation.

## Local checks

```bash
npm ci --prefix scripts/release --ignore-scripts --no-audit --no-fund
./scripts/test-release-config.sh
bash scripts/test-publish-homebrew-formula.sh
actionlint .github/workflows/*.yml
./scripts/tuist-silent.sh build iDocs
./scripts/tuist-silent.sh test
```

For a final candidate, build the native archive before publication, pack the wrapper once, then run `verify-package.mjs` with absolute wrapper/archive paths and the engine-selected version. The consumer must never import the source tree or build/repack. Remote rehearsals, synthetic PRs and test releases are excluded.

## Historical squash compatibility (2026-11-07)

Historical standard GitHub PR squash envelopes are ordinary commits: their full
Conventional Commit body must validate. Thin `release-commit-analyzer.mjs` and
`release-notes-generator.mjs` adapters use the same message projection and forward
all existing options to the official plugins. True multi-parent merges retain
original messages and complete breaking notes. Empty/malformed/nested bodies and
invalid skip-marker messages still fail. No SHA exemption, baseline fabrication
or Git history rewrite is used.

Recovery requires the sealed original release notes to be a string and exactly
match any existing Release before asset writes. After asset reconciliation, recheck
the identity and notes before publishing a draft, then verify them on final
readback. Missing or conflicting notes stop recovery; an existing body is never
replaced. Only an entirely absent Release is created using the original notes.
