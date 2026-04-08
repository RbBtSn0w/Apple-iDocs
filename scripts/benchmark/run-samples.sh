#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"
source scripts/benchmark/common.sh

RUN_ID="${1:-run-$(date +%Y%m%d-%H%M%S)}"
COLD_SAMPLES="${COLD_SAMPLES:-1}"
WARM_SAMPLES="${WARM_SAMPLES:-9}"
TARGETS="${TARGETS:-idocs-cli,apple-docs-mcp,apple-doc-mcp,sosumi-ai}"
SHARED_LIMIT="${SHARED_LIMIT:-0}"

RESULT_FILE="specs/008-mcp-service-benchmark/artifacts/results/${RUN_ID}/records.jsonl"
if [[ -f "$RESULT_FILE" ]]; then
  rm -f "$RESULT_FILE"
fi

for attempt in $(seq 1 "$COLD_SAMPLES"); do
  scripts/benchmark/reset-target-state.sh all >/dev/null
  APPEND_RECORDS=1 SAMPLE_CLASS=cold ATTEMPT_INDEX="$attempt" TARGET_FILTER="$TARGETS" SHARED_LIMIT="$SHARED_LIMIT" \
    scripts/benchmark/run-shared-scenarios.sh "${RUN_ID}"
done

for attempt in $(seq 1 "$WARM_SAMPLES"); do
  APPEND_RECORDS=1 SAMPLE_CLASS=warm ATTEMPT_INDEX="$((COLD_SAMPLES + attempt))" TARGET_FILTER="$TARGETS" SHARED_LIMIT="$SHARED_LIMIT" \
    scripts/benchmark/run-shared-scenarios.sh "${RUN_ID}"
done

log "sampling completed for run ${RUN_ID}"
