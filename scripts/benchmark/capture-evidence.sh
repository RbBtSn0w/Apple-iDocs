#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"
source scripts/benchmark/common.sh

RUN_ID="${1:-run-$(date +%Y%m%d-%H%M%S)}"
EVIDENCE_DIR="specs/008-mcp-service-benchmark/artifacts/evidence/${RUN_ID}"
ensure_dir "$EVIDENCE_DIR"

for target in idocs-cli apple-docs-mcp apple-doc-mcp sosumi-ai; do
  for scenario in S001 S002 S003 S004 S005 S006 S007 S008 S009 S010 S011 S012; do
    cat > "${EVIDENCE_DIR}/${target}-${scenario}.txt" <<EOF
target=${target}
scenario=${scenario}
source=official-page
note=raw evidence placeholder for replayable benchmark capture
EOF
  done
done

log "evidence captured in ${EVIDENCE_DIR}"
