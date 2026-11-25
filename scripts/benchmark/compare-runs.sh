#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BASELINE_FILE="${3:-}"
if [[ -n "$BASELINE_FILE" && "$BASELINE_FILE" != /* ]]; then
  BASELINE_FILE="$PWD/$BASELINE_FILE"
fi
cd "$ROOT_DIR"
source scripts/benchmark/common.sh

BASELINE_RUN="${1:-}"
NEW_RUN="${2:-}"

if [[ -z "$BASELINE_RUN" || -z "$NEW_RUN" || "$#" -gt 3 ]]; then
  echo "usage: compare-runs.sh <baseline-run-id> <new-run-id> [baseline-scores-file]"
  exit 1
fi

BASELINE_FILE="${BASELINE_FILE:-${BENCHMARK_ROOT}/artifacts/results/${BASELINE_RUN}/scores.json}"
NEW_DIR="${BENCHMARK_ROOT}/artifacts/results/${NEW_RUN}"
OUT_FILE="${NEW_DIR}/comparison.md"

python3 - "$BASELINE_FILE" "$NEW_DIR/scores.json" "$OUT_FILE" <<'PY'
import json, sys
baseline_file, new_file, out_file = sys.argv[1], sys.argv[2], sys.argv[3]
with open(baseline_file, "r", encoding="utf-8") as f:
    baseline = {x["target_id"]: x for x in json.load(f)["target_scores"]}
with open(new_file, "r", encoding="utf-8") as f:
    current = {x["target_id"]: x for x in json.load(f)["target_scores"]}

lines = [
    "# Benchmark Run Comparison",
    "",
    "| Target | Baseline | New | Delta |",
    "|--------|----------|-----|-------|"
]

for target, row in current.items():
    b = baseline.get(target, {}).get("total_score", 0.0)
    n = row.get("total_score", 0.0)
    lines.append(f"| {target} | {b:.2f} | {n:.2f} | {n-b:+.2f} |")

with open(out_file, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))
PY

log "comparison written to ${OUT_FILE}"
