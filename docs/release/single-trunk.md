# Single-trunk scheduled publication

## Development and cadence

`main` is the only integration trunk. Short-lived feature/fix PRs target main and use reviewed Conventional Commit squash messages, including breaking-change footers. Retain branch cleanup. Remote develop may remain inactive; retirement needs separate authorization. This migration starts at main `69649730d68dcf24cfbda8d6ff79fd6682532f55` (the published `v1.10.0`); develop has no outstanding business delta. Existing dependency PR #58 stays independent.

Friday 15:00 Asia/Singapore/Asia/Shanghai is `0 7 * * 5` UTC. The same `release.yml` supports immediate `workflow_dispatch` on main after validated code merges. Ordinary push/PR CI never publishes. Schedule delivery can be delayed; a manual invocation does not bypass checks or select a version. All publication is default-off unless repository variable `RELEASE_ENABLED` equals `true`.

## Candidate, version and payload

The read-only job checks out the exact event SHA with full history/tags and runs product tests. A thin upstream semantic-release JS API dry-run executes in an isolated temporary local mirror, with real tags/notes and no service credentials. Both phases share `scripts/release/config.mjs`; no independent tag/version algorithm exists. Analysis must actually execute before false means no releasable changes. PR title/body and the actual engine-selected commit range use strict commitlint with the same Conventional Commits preset. Existing malformed commits are not exempted.

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

Download the failed run's artifact by its explicit immutable artifact ID, verify the archived plan/checksums and source commit, and check out that committed source. Confirm the remote tag's peeled SHA equals `plan.candidate`. If the tag exists but the GitHub Release or some assets are missing, first use the owning `gh` tool to repair that missing side effect: create a missing release with `gh release create TAG --verify-tag --title TAG --notes-file FILE` using the original engine-generated `plan.notes`, then `gh release upload TAG MISSING_FILES` for only absent sealed artifacts. Compare SHA-256 before accepting any existing asset. Never use `--clobber`; mismatched bytes or another tag SHA stop recovery. This creates no new version or tag and never rebuilds.

The GitHub plugin initially creates a draft and publishes it only after asset uploads. If a matching draft already exists, reuse that release ID rather than creating another release. Verify its tag/SHA, compare existing assets and upload only missing sealed files; after every required asset matches, finish with `gh release edit TAG --draft=false`. Only then continue registry recovery, which deliberately rejects draft or prerelease state.

Once the matching stable GitHub Release and native asset are available, use the same committed release tooling and authorized registry credentials to invoke `node scripts/release/release.mjs recover /absolute/verified-input VERSION`. Recovery verifies the existing tag and native asset, then uploads only missing registry bytes; conflicts fail closed. Homebrew-only recovery uses `scripts/publish-homebrew-formula.sh VERSION` with the published native checksum and scoped tap credentials. Retain the original receipt and recovered target results. No recovery operation is authorized by merely reading this document.

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
