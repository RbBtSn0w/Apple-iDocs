#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
INPUT="${2:-SwiftUI View}"

run_cli() {
  if [[ -n "${IDOCS_LOCAL_BINARY:-}" && -x "$IDOCS_LOCAL_BINARY" ]]; then
    "$IDOCS_LOCAL_BINARY" "$@"
  else
    ./scripts/tuist-silent.sh run idocs "$@"
  fi
}

if [[ "$MODE" == "--probe" ]]; then
  if run_cli --help >/dev/null; then
    echo '{"status":"success","message":"idocs cli reachable"}'
  else
    echo '{"status":"failure","message":"idocs cli not reachable"}'
    exit 1
  fi
  exit 0
fi

set +e
OUTPUT="$(run_cli search "$INPUT" 2>&1)"
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
