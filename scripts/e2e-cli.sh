#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DERIVED_DATA_PATH="${IDOCS_DERIVED_DATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData/iDocs-codex}"
IDOCS_LOCAL_BINARY_DEFAULT="$DERIVED_DATA_PATH/Build/Products/Debug/idocs"
TMP_DIRS=()

cleanup() {
  for d in "${TMP_DIRS[@]:-}"; do
    rm -rf "$d" 2>/dev/null || true
  done
}
trap cleanup EXIT

new_tmp_dir() {
  local d
  d="$(mktemp -d)"
  TMP_DIRS+=("$d")
  echo "$d"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local context="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "[FAIL] $context: expected output to contain '$needle'" >&2
    echo "------ output ------" >&2
    echo "$haystack" >&2
    echo "--------------------" >&2
    exit 1
  fi
}

assert_exit_zero() {
  local code="$1"
  local context="$2"
  if [[ "$code" -ne 0 ]]; then
    echo "[FAIL] $context: expected exit 0, got $code" >&2
    exit 1
  fi
}

RUN_CODE=""
RUN_OUTPUT=""

run_cmd_capture() {
  local out_file
  out_file="$(mktemp)"
  set +e
  "$@" >"$out_file" 2>&1
  RUN_CODE=$?
  set -e
  RUN_OUTPUT="$(cat "$out_file")"
  rm -f "$out_file"
}

echo "[E2E] Build local CLI binary"
./scripts/tuist-silent.sh build iDocs >/dev/null

if [[ ! -x "$IDOCS_LOCAL_BINARY_DEFAULT" ]]; then
  echo "[FAIL] local binary not found: $IDOCS_LOCAL_BINARY_DEFAULT" >&2
  exit 1
fi

echo "[E2E] Path A: npm link flow"
TMP_PREFIX="$(new_tmp_dir)/npm-prefix"
mkdir -p "$TMP_PREFIX"
export npm_config_prefix="$TMP_PREFIX"
export PATH="$TMP_PREFIX/bin:$PATH"

npm --prefix npm run link-local >/dev/null
(cd npm && npm link >/dev/null)

if ! command -v idocs >/dev/null 2>&1; then
  echo "[FAIL] idocs not found on PATH after npm link" >&2
  exit 1
fi

run_cmd_capture idocs --help
assert_exit_zero "$RUN_CODE" "idocs --help (link flow)"
assert_contains "$RUN_OUTPUT" "USAGE: idocs <subcommand>" "idocs --help (link flow)"

run_cmd_capture idocs search "Combine Publisher"
assert_exit_zero "$RUN_CODE" "idocs search (link flow)"
assert_contains "$RUN_OUTPUT" "source:" "idocs search source observability (link flow)"

run_cmd_capture idocs fetch "/documentation/swiftui/view"
assert_exit_zero "$RUN_CODE" "idocs fetch (link flow)"
assert_contains "$RUN_OUTPUT" "[source:" "idocs fetch source observability (link flow)"
assert_contains "$RUN_OUTPUT" "# View" "idocs fetch markdown content (link flow)"

run_cmd_capture idocs list --category Frameworks
assert_exit_zero "$RUN_CODE" "idocs list (link flow)"
assert_contains "$RUN_OUTPUT" "/documentation/" "idocs list structured path output (link flow)"

echo "[E2E] Path B: npm pack + local install flow"
TGZ_FILE="$(cd npm && npm pack --json | jq -r '.[0].filename')"
if [[ -z "$TGZ_FILE" || ! -f "npm/$TGZ_FILE" ]]; then
  echo "[FAIL] npm pack did not produce expected tgz file" >&2
  exit 1
fi

TMP_INSTALL_ROOT="$(new_tmp_dir)"
TMP_APP_DIR="$TMP_INSTALL_ROOT/app"
mkdir -p "$TMP_APP_DIR"
(cd "$TMP_APP_DIR" && npm init -y >/dev/null)
(cd "$TMP_APP_DIR" && npm i "$ROOT_DIR/npm/$TGZ_FILE" >/dev/null)

IDOCS_LOCAL_BINARY="$IDOCS_LOCAL_BINARY_DEFAULT" \
  npm --prefix "$TMP_APP_DIR/node_modules/idocs-cli" run link-local >/dev/null

BIN="$TMP_APP_DIR/node_modules/.bin/idocs"
if [[ ! -x "$BIN" ]]; then
  echo "[FAIL] installed idocs binary shim missing: $BIN" >&2
  exit 1
fi

run_cmd_capture "$BIN" --help
assert_exit_zero "$RUN_CODE" "idocs --help (pack flow)"
assert_contains "$RUN_OUTPUT" "USAGE: idocs <subcommand>" "idocs --help (pack flow)"

run_cmd_capture "$BIN" search "SwiftUI"
assert_exit_zero "$RUN_CODE" "idocs search (pack flow)"
assert_contains "$RUN_OUTPUT" "source:" "idocs search source observability (pack flow)"

echo "[PASS] E2E CLI checks completed."
