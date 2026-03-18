#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SPEC_FILE="specs/006-cli-multisource-docs/spec.md"
TRACE_FILE="specs/006-cli-multisource-docs/acceptance-traceability.md"

failures=0

if [[ ! -f "$SPEC_FILE" ]]; then
  echo "[FAIL] Traceability Gate: missing $SPEC_FILE"
  exit 1
fi

if [[ ! -f "$TRACE_FILE" ]]; then
  echo "[FAIL] Traceability Gate: missing $TRACE_FILE"
  exit 1
fi

ids=()
while IFS= read -r id; do
  ids+=("$id")
done < <(rg -o 'FR-[0-9]{3}|SC-[0-9]{3}' "$SPEC_FILE" | sort -u)

for id in "${ids[@]}"; do
  if ! rg -n "^\|\s*${id}\s*\|" "$TRACE_FILE" >/dev/null 2>&1; then
    echo "[FAIL] Traceability Gate: ${id} missing in acceptance matrix"
    failures=$((failures + 1))
    continue
  fi

  row="$(rg -n "^\|\s*${id}\s*\|" "$TRACE_FILE" | head -n1 | cut -d: -f2-)"
  if ! grep -Eq 'Tests/|scripts/' <<<"$row"; then
    echo "[FAIL] Traceability Gate: ${id} has no automated check reference"
    failures=$((failures + 1))
    continue
  fi

  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    if [[ ! -e "$ref" ]]; then
      echo "[FAIL] Traceability Gate: ${id} references missing path '$ref'"
      failures=$((failures + 1))
    fi
  done < <(grep -oE 'Tests/[^` ,|;)]*\.swift|scripts/[^` ,|;)]*\.sh' <<<"$row" | sort -u)
done

if [[ "$failures" -gt 0 ]]; then
  echo "[FAIL] Traceability Gate: ${failures} issue(s) found"
  exit 1
fi

echo "[PASS] Traceability Gate"
