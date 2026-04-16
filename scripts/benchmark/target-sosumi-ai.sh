#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
INPUT="${2:-SwiftUI View}"

run_client() {
  node scripts/benchmark/mcp-client.mjs \
    --command-bin npx \
    --command-arg -y \
    --command-arg mcp-remote \
    --command-arg https://sosumi.ai/mcp \
    --input "$1"
}

if [[ "$MODE" == "--probe" ]]; then
  run_client "SwiftUI View"
  exit $?
fi

run_client "$INPUT"
