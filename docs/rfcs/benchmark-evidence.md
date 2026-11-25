# Documentation benchmark evidence

The benchmark scripts compare the shipped CLI and external tools in a separate environment. Shared [fixtures](../../scripts/benchmark/fixtures/) describe the target configurations, scenario matrix, golden dataset, and seeded search audit pool. The Swift tests and benchmark runners use the same inputs. Local corpus runs write generated results under `scripts/benchmark/artifacts/`.

The full benchmark distinguishes cold and warm samples and retains case-level records, normalized evidence, and assertions. Claim and slot scores measure evidence against the golden dataset, and ambiguous samples can be flagged for review. Aggregate reports are traceable to the target, scenario, and attempt. Token counts and readability are agent-format signals alongside evidence accuracy and completeness.

For a baseline saved before the directory migration or in another checkout, pass its `scores.json` as the third argument to `./scripts/benchmark/compare-runs.sh <baseline-run-id> <new-run-id> <baseline-scores-file>`. The new run and comparison report use the current artifact directory.

The [Search Quality Race](../../.github/workflows/search-quality-race.yml) samples cases reproducibly by seed and records exact competitor versions. It compares remote behavior, so its reports cannot establish the quality of iDocs' local Xcode retrieval. Keep structured resolution, canonical fetch, and exploratory search outcomes visible by capability. Only eligible iDocs resolve/fetch golden-truth failures enter automatic P0 issue collection. Infrastructure, network, and competitor failures stay distinguishable from product evidence failures. Issue fingerprints group repeated observations of the same actionable failures.

The [runner tests](../../scripts/benchmark/tests/run-random-search-audit.test.mjs) exercise deterministic sampling and reporting on mock targets. Use their offline path to check audit plumbing without running a live comparison.
