#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
INPUT="${2:-SwiftUI View}"

CMD="npx -y mcp-remote https://sosumi.ai/mcp"

if [[ "$MODE" == "--probe" ]]; then
  node scripts/benchmark/mcp-client.mjs --command "$CMD" --input "SwiftUI View"
  exit $?
fi

node scripts/benchmark/mcp-client.mjs --command "$CMD" --input "$INPUT"
