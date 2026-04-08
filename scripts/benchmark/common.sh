#!/usr/bin/env bash
set -euo pipefail

BENCHMARK_ROOT="specs/008-mcp-service-benchmark"

log() {
  printf '[benchmark] %s\n' "$*"
}

now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

now_ms() {
  python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
}

ensure_dir() {
  mkdir -p "$1"
}

estimate_tokens() {
  local chars="${1:-0}"
  if [[ "$chars" -le 0 ]]; then
    echo 0
  else
    echo $(( (chars + 3) / 4 ))
  fi
}

json_get() {
  local file="$1"
  local path="$2"
  python3 - "$file" "$path" <<'PY'
import json, sys
path = sys.argv[2].split(".")
with open(sys.argv[1], "r", encoding="utf-8") as f:
    value = json.load(f)
for item in path:
    if item == "":
        continue
    if isinstance(value, list):
        value = value[int(item)]
    else:
        value = value[item]
if isinstance(value, (dict, list)):
    print(json.dumps(value, ensure_ascii=False))
else:
    print(value)
PY
}
