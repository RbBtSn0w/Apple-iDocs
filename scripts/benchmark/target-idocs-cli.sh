#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
INPUT="${2:-SwiftUI View}"

if [[ "$MODE" == "--probe" ]]; then
  if ./scripts/tuist-silent.sh run idocs --help >/dev/null 2>&1; then
    echo '{"status":"success","message":"idocs cli reachable"}'
  else
    echo '{"status":"failure","message":"idocs cli not reachable"}'
    exit 1
  fi
  exit 0
fi

set +e
OUTPUT="$(./scripts/tuist-silent.sh run idocs search "$INPUT" 2>&1)"
CODE=$?
set -e

if [[ $CODE -eq 0 ]]; then
  python3 - "$OUTPUT" <<'PY'
import json, sys
print(json.dumps({"status":"success","result":sys.argv[1]}, ensure_ascii=False))
PY
else
  python3 - "$OUTPUT" <<'PY'
import json, sys
print(json.dumps({"status":"failure","error":sys.argv[1]}, ensure_ascii=False))
PY
  exit 1
fi
