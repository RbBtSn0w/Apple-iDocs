#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"
source scripts/benchmark/common.sh

BASELINE_RUN="${1:-}"
NEW_RUN="${2:-}"

if [[ -z "$BASELINE_RUN" || -z "$NEW_RUN" ]]; then
  echo "usage: compare-runs.sh <baseline-run-id> <new-run-id>"
  exit 1
fi

BASE_DIR="specs/008-mcp-service-benchmark/artifacts/results/${BASELINE_RUN}"
NEW_DIR="specs/008-mcp-service-benchmark/artifacts/results/${NEW_RUN}"
OUT_FILE="specs/008-mcp-service-benchmark/artifacts/results/${NEW_RUN}/comparison.md"

python3 - "$BASE_DIR/scores.json" "$NEW_DIR/scores.json" "$OUT_FILE" <<'PY'
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
