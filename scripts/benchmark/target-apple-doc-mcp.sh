#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
INPUT="${2:-SwiftUI View}"

CMD="npx apple-doc-mcp-server@latest"
REJECT_PATTERN="No Technology Selected"

if [[ "$MODE" == "--probe" ]]; then
  node scripts/benchmark/mcp-client.mjs --command "$CMD" --input "SwiftUI View" --reject-pattern "$REJECT_PATTERN"
  exit $?
fi

node scripts/benchmark/mcp-client.mjs --command "$CMD" --input "$INPUT" --reject-pattern "$REJECT_PATTERN"
