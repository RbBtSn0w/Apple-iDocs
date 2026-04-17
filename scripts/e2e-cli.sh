#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MODE="${1:-offline}"
if [[ "$MODE" != "offline" && "$MODE" != "live" ]]; then
  echo "Usage: $0 [offline|live]" >&2
  exit 1
fi

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

assert_search_observability_or_no_result() {
  local output="$1"
  local context="$2"
  if [[ "$output" == *"source:"* ]]; then
    return 0
  fi
  if [[ "$output" == *"No matching documentation found."* ]]; then
    return 0
  fi
  echo "[FAIL] $context: expected output to contain either 'source:' or 'No matching documentation found.'" >&2
  echo "------ output ------" >&2
  echo "$output" >&2
  echo "--------------------" >&2
  exit 1
}

assert_exit_zero() {
  local code="$1"
  local context="$2"
  if [[ "$code" -ne 0 ]]; then
    echo "[FAIL] $context: expected exit 0, got $code" >&2
    exit 1
  fi
}

assert_exit_nonzero() {
  local code="$1"
  local context="$2"
  if [[ "$code" -eq 0 ]]; then
    echo "[FAIL] $context: expected non-zero exit, got 0" >&2
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

echo "[E2E] Mode: $MODE"
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

echo "[E2E] Path A0: failed fetch-binary preserves existing linked binary"
run_cmd_capture env -u IDOCS_LOCAL_BINARY bash -lc "cd \"$ROOT_DIR\" && IDOCS_RELEASE_BASE_URL='https://127.0.0.1:9/v{version}' npm --prefix npm run fetch-binary"
assert_exit_nonzero "$RUN_CODE" "npm run fetch-binary should fail when release asset is unavailable"

if [[ ! -x "$ROOT_DIR/npm/dist/idocs" ]]; then
  echo "[FAIL] linked binary should remain after failed fetch-binary" >&2
  exit 1
fi

run_cmd_capture idocs --help
assert_exit_zero "$RUN_CODE" "idocs --help after failed fetch-binary"
assert_contains "$RUN_OUTPUT" "USAGE: idocs <subcommand>" "idocs --help after failed fetch-binary"

if [[ "$MODE" == "live" ]]; then
  run_cmd_capture idocs search "Combine Publisher"
  assert_exit_zero "$RUN_CODE" "idocs search (link flow)"
  assert_search_observability_or_no_result "$RUN_OUTPUT" "idocs search contract (link flow)"

  run_cmd_capture idocs fetch "/documentation/swiftui/view"
  assert_exit_zero "$RUN_CODE" "idocs fetch (link flow)"
  assert_contains "$RUN_OUTPUT" "[source:" "idocs fetch source observability (link flow)"
  assert_contains "$RUN_OUTPUT" "# View" "idocs fetch markdown content (link flow)"

  run_cmd_capture idocs list --category Frameworks
  assert_exit_zero "$RUN_CODE" "idocs list (link flow)"
  assert_contains "$RUN_OUTPUT" "/documentation/" "idocs list structured path output (link flow)"
fi

echo "[E2E] Path B: npm pack + local install flow"
TGZ_FILE="$(cd npm && npm pack --json | jq -r '.[0].filename')"
if [[ -z "$TGZ_FILE" || ! -f "npm/$TGZ_FILE" ]]; then
  echo "[FAIL] npm pack did not produce expected tgz file" >&2
  exit 1
fi

echo "[E2E] Path B0: npm pack fails fast when release asset cannot be downloaded"
TMP_FAIL_ROOT="$(new_tmp_dir)"
TMP_FAIL_APP_DIR="$TMP_FAIL_ROOT/app"
mkdir -p "$TMP_FAIL_APP_DIR"
(cd "$TMP_FAIL_APP_DIR" && npm init -y >/dev/null)

# This negative-path install must not inherit the CI job's IDOCS_LOCAL_BINARY,
# otherwise npm postinstall will skip the download and the assertion becomes invalid.
run_cmd_capture env -u IDOCS_LOCAL_BINARY bash -lc "cd \"$TMP_FAIL_APP_DIR\" && IDOCS_RELEASE_BASE_URL='https://127.0.0.1:9/v{version}' npm i \"$ROOT_DIR/npm/$TGZ_FILE\""
assert_exit_nonzero "$RUN_CODE" "npm install should fail fast when release asset is unavailable"
assert_contains "$RUN_OUTPUT" "Binary download failed. Install aborted" "npm install fail-fast message"

TMP_INSTALL_ROOT="$(new_tmp_dir)"
TMP_APP_DIR="$TMP_INSTALL_ROOT/app"
mkdir -p "$TMP_APP_DIR"
(cd "$TMP_APP_DIR" && npm init -y >/dev/null)
(cd "$TMP_APP_DIR" && IDOCS_LOCAL_BINARY="$IDOCS_LOCAL_BINARY_DEFAULT" npm i "$ROOT_DIR/npm/$TGZ_FILE" >/dev/null)

IDOCS_LOCAL_BINARY="$IDOCS_LOCAL_BINARY_DEFAULT" \
  npm --prefix "$TMP_APP_DIR/node_modules/@rbbtsn0w/idocs" run link-local >/dev/null

BIN="$TMP_APP_DIR/node_modules/.bin/idocs"
if [[ ! -x "$BIN" ]]; then
  echo "[FAIL] installed idocs binary shim missing: $BIN" >&2
  exit 1
fi

run_cmd_capture "$BIN" --help
assert_exit_zero "$RUN_CODE" "idocs --help (pack flow)"
assert_contains "$RUN_OUTPUT" "USAGE: idocs <subcommand>" "idocs --help (pack flow)"

if [[ "$MODE" == "live" ]]; then
  run_cmd_capture "$BIN" search "SwiftUI"
  assert_exit_zero "$RUN_CODE" "idocs search (pack flow)"
  assert_search_observability_or_no_result "$RUN_OUTPUT" "idocs search contract (pack flow)"
fi

echo "[PASS] E2E CLI checks completed (mode: $MODE)."
