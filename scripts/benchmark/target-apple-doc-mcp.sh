#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
INPUT="${2:-SwiftUI View}"
REJECT_PATTERN="No Technology Selected"

run_client() {
  node scripts/benchmark/mcp-client.mjs \
    --command-bin npx \
    --command-arg apple-doc-mcp-server@latest \
    --input "$1" \
    --reject-pattern "$REJECT_PATTERN"
}

if [[ "$MODE" == "--probe" ]]; then
  run_client "SwiftUI View"
  exit $?
fi

run_client "$INPUT"
