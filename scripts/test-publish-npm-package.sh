#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/scripts/publish-npm-package.sh"
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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local context="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "[FAIL] $context: expected output not to contain '$needle'" >&2
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

write_package_json() {
  local package_dir="$1"
  mkdir -p "$package_dir"
  cat >"$package_dir/package.json" <<'EOF'
{
  "name": "@rbbtsn0w/idocs",
  "version": "1.1.2"
}
EOF
}

write_npm_stub() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat >"$bin_dir/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "$*" >> "${NPM_STUB_LOG:?}"

case "${1:-}" in
  view)
    exit "${NPM_STUB_VIEW_EXIT:-1}"
    ;;
  publish)
    exit "${NPM_STUB_PUBLISH_EXIT:-0}"
    ;;
  config)
    exit 0
    ;;
esac

echo "unexpected npm invocation: $*" >&2
exit 99
EOF
  chmod +x "$bin_dir/npm"
}

echo "[TEST] publish script skips npmjs.org publish when version already exists"
TMP_PACKAGE_DIR="$(new_tmp_dir)"
TMP_BIN_DIR="$(new_tmp_dir)"
TMP_LOG_FILE="$(new_tmp_dir)/npm.log"
write_package_json "$TMP_PACKAGE_DIR"
write_npm_stub "$TMP_BIN_DIR"

run_cmd_capture env \
  PATH="$TMP_BIN_DIR:$PATH" \
  NPM_STUB_LOG="$TMP_LOG_FILE" \
  NPM_STUB_VIEW_EXIT=0 \
  IDOCS_NPM_PACKAGE_DIR="$TMP_PACKAGE_DIR" \
  bash "$SCRIPT_PATH" npmjs
assert_exit_zero "$RUN_CODE" "publish-npm-package npmjs skip existing version"
assert_contains "$RUN_OUTPUT" "already exists on npmjs.org; skipping publish." "npmjs skip message"
assert_not_contains "$(cat "$TMP_LOG_FILE")" "publish --provenance --access public" "npmjs skip should not publish"

echo "[TEST] publish script fails loudly when npmjs.org publish fails"
TMP_PACKAGE_DIR="$(new_tmp_dir)"
TMP_BIN_DIR="$(new_tmp_dir)"
TMP_LOG_FILE="$(new_tmp_dir)/npm.log"
write_package_json "$TMP_PACKAGE_DIR"
write_npm_stub "$TMP_BIN_DIR"

run_cmd_capture env \
  PATH="$TMP_BIN_DIR:$PATH" \
  NPM_STUB_LOG="$TMP_LOG_FILE" \
  NPM_STUB_VIEW_EXIT=1 \
  NPM_STUB_PUBLISH_EXIT=17 \
  IDOCS_NPM_PACKAGE_DIR="$TMP_PACKAGE_DIR" \
  bash "$SCRIPT_PATH" npmjs
assert_exit_nonzero "$RUN_CODE" "publish-npm-package npmjs should fail when publish fails"
assert_contains "$(cat "$TMP_LOG_FILE")" "publish --provenance --access public --registry https://registry.npmjs.org" "npmjs publish command should target npmjs.org explicitly"

echo "[TEST] publish script configures GitHub Packages registry before checking version"
TMP_PACKAGE_DIR="$(new_tmp_dir)"
TMP_BIN_DIR="$(new_tmp_dir)"
TMP_LOG_FILE="$(new_tmp_dir)/npm.log"
write_package_json "$TMP_PACKAGE_DIR"
write_npm_stub "$TMP_BIN_DIR"

run_cmd_capture env \
  PATH="$TMP_BIN_DIR:$PATH" \
  NODE_AUTH_TOKEN="test-token" \
  NPM_STUB_LOG="$TMP_LOG_FILE" \
  NPM_STUB_VIEW_EXIT=0 \
  IDOCS_NPM_PACKAGE_DIR="$TMP_PACKAGE_DIR" \
  bash "$SCRIPT_PATH" github
assert_exit_zero "$RUN_CODE" "publish-npm-package github skip existing version"
assert_contains "$(cat "$TMP_LOG_FILE")" "config set @rbbtsn0w:registry https://npm.pkg.github.com" "github registry scope config"
assert_contains "$(cat "$TMP_LOG_FILE")" "config set //npm.pkg.github.com/:_authToken test-token" "github auth config"
assert_contains "$RUN_OUTPUT" "already exists on GitHub Packages; skipping publish." "github skip message"

echo "[PASS] publish-npm-package checks completed."
