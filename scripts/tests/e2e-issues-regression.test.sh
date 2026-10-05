#!/usr/bin/env bash
# End-to-end regression test suite for GitHub Issues #53 and #54.
# - Issue #53: idocs fetch preserves DocC list items and tables in release notes.
# - Issue #54: idocs search bounds results, recalls Xcode guides, suppresses
#   technologies duplicates, and eliminates stderr cancellation log spam.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

DERIVED_DATA_PATH="${IDOCS_DERIVED_DATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData/iDocs-codex}"
IDOCS_BIN="${IDOCS_LOCAL_BINARY:-$DERIVED_DATA_PATH/Build/Products/Debug/idocs}"

if [[ ! -x "$IDOCS_BIN" ]]; then
  echo "[E2E] Building local idocs binary..."
  ./scripts/tuist-silent.sh build iDocs >/dev/null
fi

if [[ ! -x "$IDOCS_BIN" ]]; then
  # Fallback search in DerivedData
  IDOCS_BIN="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/Debug/idocs" -type f 2>/dev/null | head -n 1)"
fi

if [[ -z "$IDOCS_BIN" || ! -x "$IDOCS_BIN" ]]; then
  echo "FAIL: Could not locate built idocs binary at $IDOCS_BIN" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "=== Running E2E Regression Tests for Issues #53 & #54 ==="
echo "Using binary: $IDOCS_BIN"

# -----------------------------------------------------------------------------
# Test 1 (Issue #53): idocs fetch renders DocC list items and tables
# -----------------------------------------------------------------------------
echo "[Test 1/5] Issue #53: idocs fetch renders bullet points in release notes..."
FETCH_OUT="$TMP_DIR/fetch_out.md"
set +e
"$IDOCS_BIN" fetch "/documentation/xcode-release-notes/xcode-27-release-notes" >"$FETCH_OUT" 2>"$TMP_DIR/fetch_err.log"
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "FAIL: idocs fetch failed with exit code $EXIT_CODE" >&2
  cat "$TMP_DIR/fetch_err.log" >&2
  exit 1
fi

# Assert bullet items are rendered
if ! grep -q -E "^- " "$FETCH_OUT"; then
  echo "FAIL: idocs fetch output does not contain any '- ' markdown bullet points" >&2
  head -n 50 "$FETCH_OUT" >&2
  exit 1
fi

# Assert specific release note headings exist
if ! grep -q "Localization" "$FETCH_OUT"; then
  echo "FAIL: idocs fetch output missing Localization heading" >&2
  exit 1
fi

echo "  -> OK: Markdown bullet points rendered successfully"

# -----------------------------------------------------------------------------
# Test 2 (Issue #53): idocs fetch --json has 0 dropped content diagnostics
# -----------------------------------------------------------------------------
echo "[Test 2/5] Issue #53: idocs fetch --json reports zero content_blocks_not_array diagnostics..."
FETCH_JSON="$TMP_DIR/fetch_out.json"
set +e
"$IDOCS_BIN" fetch "/documentation/xcode-release-notes/xcode-27-release-notes" --json >"$FETCH_JSON" 2>"$TMP_DIR/fetch_json_err.log"
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "FAIL: idocs fetch --json failed with exit code $EXIT_CODE" >&2
  cat "$TMP_DIR/fetch_json_err.log" >&2
  exit 1
fi

if grep -q "content_blocks_not_array" "$FETCH_JSON"; then
  echo "FAIL: fetch JSON contains content_blocks_not_array diagnostic" >&2
  grep "content_blocks_not_array" "$FETCH_JSON" >&2
  exit 1
fi

if grep -q "block_items_not_array" "$FETCH_JSON"; then
  echo "FAIL: fetch JSON contains block_items_not_array diagnostic" >&2
  grep "block_items_not_array" "$FETCH_JSON" >&2
  exit 1
fi

echo "  -> OK: Zero dropped block diagnostics in JSON output"

# -----------------------------------------------------------------------------
# Test 3 (Issue #54): idocs search agent guides - bounded, recalled, clean stderr
# -----------------------------------------------------------------------------
echo "[Test 3/5] Issue #54: idocs search recalls agent localization guide without log spam..."
SEARCH_AGENTS_JSON="$TMP_DIR/search_agents.json"
SEARCH_AGENTS_ERR="$TMP_DIR/search_agents_err.log"
set +e
"$IDOCS_BIN" search "localizing your app using agents" --json >"$SEARCH_AGENTS_JSON" 2>"$SEARCH_AGENTS_ERR"
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "FAIL: idocs search failed with exit code $EXIT_CODE" >&2
  cat "$SEARCH_AGENTS_ERR" >&2
  exit 1
fi

# Assert no cancellation log noise on stderr
if grep -q "Attempt 1 failed with error: cancelled" "$SEARCH_AGENTS_ERR"; then
  echo "FAIL: idocs search stderr contains cancelled log noise" >&2
  cat "$SEARCH_AGENTS_ERR" >&2
  exit 1
fi

# Assert agent localization guide is recalled
if ! jq -e '.selected_paths[] | select(contains("localizing-your-app-using-agents"))' "$SEARCH_AGENTS_JSON" >/dev/null; then
  echo "FAIL: idocs search did not recall /documentation/xcode/localizing-your-app-using-agents" >&2
  head -n 40 "$SEARCH_AGENTS_JSON" >&2
  exit 1
fi

# Assert /documentation/technologies is not duplicated (count <= 1)
TECH_COUNT="$(jq '[.selected_paths[] | select(. == "/documentation/technologies")] | length' "$SEARCH_AGENTS_JSON")"
if [[ "$TECH_COUNT" -gt 1 ]]; then
  echo "FAIL: idocs search returned $TECH_COUNT duplicate /documentation/technologies entries" >&2
  exit 1
fi

# Assert bounded count (<= 50)
RESULT_COUNT="$(jq '.selected_paths | length' "$SEARCH_AGENTS_JSON")"
if [[ "$RESULT_COUNT" -gt 50 || "$RESULT_COUNT" -eq 0 ]]; then
  echo "FAIL: idocs search returned unexpected result count ($RESULT_COUNT)" >&2
  exit 1
fi

echo "  -> OK: Recalled agent guide ($RESULT_COUNT results), 0 cancellation noise, 0 tech duplication"

# -----------------------------------------------------------------------------
# Test 4 (Issue #54): idocs search String Catalog recall
# -----------------------------------------------------------------------------
echo "[Test 4/5] Issue #54: idocs search recalls String Catalog articles..."
SEARCH_CATALOG_JSON="$TMP_DIR/search_catalog.json"
set +e
"$IDOCS_BIN" search "String Catalog" --json >"$SEARCH_CATALOG_JSON" 2>"$TMP_DIR/search_catalog_err.log"
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "FAIL: idocs search 'String Catalog' failed with exit code $EXIT_CODE" >&2
  cat "$TMP_DIR/search_catalog_err.log" >&2
  exit 1
fi

if ! jq -e '.selected_paths[] | select(contains("string-catalog") or contains("catalog"))' "$SEARCH_CATALOG_JSON" >/dev/null; then
  echo "FAIL: idocs search 'String Catalog' did not recall string catalog articles" >&2
  head -n 40 "$SEARCH_CATALOG_JSON" >&2
  exit 1
fi

echo "  -> OK: Recalled String Catalog documentation"

# -----------------------------------------------------------------------------
# Test 5: Disk Cache Isolation & Hit Verification
# -----------------------------------------------------------------------------
echo "[Test 5/5] Disk cache isolation and subsequent hit verification..."
CACHE_DIR="$TMP_DIR/isolated_cache"
mkdir -p "$CACHE_DIR"

# Run 1: Remote fetch into isolated cache
set +e
IDOCS_CACHE_PATH="$CACHE_DIR" "$IDOCS_BIN" fetch "/documentation/xcode-release-notes/xcode-27-release-notes" --json >"$TMP_DIR/cache_run1.json" 2>&1
EXIT1=$?
# Run 2: Read from isolated cache
IDOCS_CACHE_PATH="$CACHE_DIR" "$IDOCS_BIN" fetch "/documentation/xcode-release-notes/xcode-27-release-notes" --json >"$TMP_DIR/cache_run2.json" 2>&1
EXIT2=$?
set -e

if [[ $EXIT1 -ne 0 || $EXIT2 -ne 0 ]]; then
  echo "FAIL: Isolated cache fetch failed (Run 1: $EXIT1, Run 2: $EXIT2)" >&2
  exit 1
fi

if ! grep -q '"status":"hit"' "$TMP_DIR/cache_run2.json"; then
  echo "FAIL: Second fetch run did not hit disk cache" >&2
  cat "$TMP_DIR/cache_run2.json" >&2
  exit 1
fi

echo "  -> OK: Disk cache hit verified"

echo "=== All E2E Regression Tests Passed (5/5) ==="
exit 0
