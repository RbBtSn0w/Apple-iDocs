#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"
source scripts/benchmark/common.sh

RUN_ID="${1:-run-$(date +%Y%m%d-%H%M%S)}"
RESULT_DIR="specs/008-mcp-service-benchmark/artifacts/results/${RUN_ID}"
COLD_SAMPLES="${COLD_SAMPLES:-1}"
WARM_SAMPLES="${WARM_SAMPLES:-9}"
ensure_dir "$RESULT_DIR"

log "run id: ${RUN_ID}"
scripts/benchmark/bootstrap-project-mcp.sh
scripts/benchmark/probe-targets.sh
scripts/benchmark/capture-evidence.sh "$RUN_ID"
COLD_SAMPLES="$COLD_SAMPLES" WARM_SAMPLES="$WARM_SAMPLES" SHARED_LIMIT="${SHARED_LIMIT:-0}" \
  scripts/benchmark/run-samples.sh "$RUN_ID"

swift scripts/benchmark/aggregate-results.swift \
  "${RESULT_DIR}/records.jsonl" \
  "${RESULT_DIR}/aggregates.json"

swift scripts/benchmark/score-results.swift \
  "${RESULT_DIR}/aggregates.json" \
  "${RESULT_DIR}/scores.json"

swift scripts/benchmark/evaluate-format-readiness.swift \
  "${RESULT_DIR}/records.jsonl" \
  "${RESULT_DIR}/format-readiness.json"

swift scripts/benchmark/render-report.swift \
  "${RESULT_DIR}/scores.json" \
  "${RESULT_DIR}/format-readiness.json" \
  "${RESULT_DIR}/aggregates.json" \
  "${RESULT_DIR}/records.jsonl" \
  "${RESULT_DIR}/report.md"

log "benchmark completed. report: ${RESULT_DIR}/report.md"
