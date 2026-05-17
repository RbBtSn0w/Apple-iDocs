#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/scripts/publish-homebrew-formula.sh"
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

assert_file_contains() {
  local path="$1"
  local needle="$2"
  local context="$3"
  if [[ ! -f "$path" ]]; then
    echo "[FAIL] $context: expected file to exist: $path" >&2
    exit 1
  fi
  assert_contains "$(cat "$path")" "$needle" "$context"
}

assert_exit_zero() {
  local code="$1"
  local context="$2"
  if [[ "$code" -ne 0 ]]; then
    echo "[FAIL] $context: expected exit 0, got $code" >&2
    exit 1
  fi
}

write_package_json() {
  local package_dir="$1"
  mkdir -p "$package_dir"
  cat >"$package_dir/package.json" <<'JSON'
{
  "name": "@rbbtsn0w/idocs",
  "version": "1.2.3"
}
JSON
}

write_git_stub() {
  local bin_dir="$1"
  local log_file="$2"
  mkdir -p "$bin_dir"
  cat >"$bin_dir/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "git $*" >> "${GIT_STUB_LOG:?}"

case "${1:-}" in
  clone)
    mkdir -p "${@: -1}"
    ;;
  -C)
    case "${3:-}" in
      config|add|commit|push)
        ;;
      diff)
        if [[ "${4:-}" == "--quiet" ]]; then
          exit "${GIT_STUB_DIFF_EXIT:-1}"
        fi
        ;;
      *)
        echo "unexpected git -C invocation: $*" >&2
        exit 99
        ;;
    esac
    ;;
  *)
    echo "unexpected git invocation: $*" >&2
    exit 99
    ;;
esac
EOF
  chmod +x "$bin_dir/git"
  : > "$log_file"
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

echo "[TEST] publish script generates an idocs formula with release URL, checksum, and libexec wrapper"
TMP_PACKAGE_DIR="$(new_tmp_dir)"
TMP_TAP_DIR="$(new_tmp_dir)"
TMP_CHECKSUM_FILE="$(new_tmp_dir)/idocs-darwin-arm64.sha256"
TMP_BIN_DIR="$(new_tmp_dir)"
TMP_GIT_LOG="$(new_tmp_dir)/git.log"
write_package_json "$TMP_PACKAGE_DIR"
TEST_SHA256="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
printf '%s  idocs-darwin-arm64.tar.gz\n' "$TEST_SHA256" > "$TMP_CHECKSUM_FILE"
write_git_stub "$TMP_BIN_DIR" "$TMP_GIT_LOG"

run_cmd_capture env \
  PATH="$TMP_BIN_DIR:$PATH" \
  GIT_STUB_LOG="$TMP_GIT_LOG" \
  HOMEBREW_TAP_LOCAL_PATH="$TMP_TAP_DIR" \
  IDOCS_NPM_PACKAGE_DIR="$TMP_PACKAGE_DIR" \
  IDOCS_HOMEBREW_CHECKSUM_FILE="$TMP_CHECKSUM_FILE" \
  IDOCS_HOMEBREW_RELEASE_BASE_URL="https://example.invalid/releases/download/v{version}" \
  bash "$SCRIPT_PATH"
assert_exit_zero "$RUN_CODE" "publish-homebrew-formula first write"
FORMULA_PATH="$TMP_TAP_DIR/Formula/idocs.rb"
assert_file_contains "$FORMULA_PATH" 'class Idocs < Formula' "formula class"
assert_file_contains "$FORMULA_PATH" 'url "https://example.invalid/releases/download/v1.2.3/idocs-darwin-arm64.tar.gz"' "formula release URL"
assert_file_contains "$FORMULA_PATH" "sha256 \"$TEST_SHA256\"" "formula checksum"
assert_file_contains "$FORMULA_PATH" 'depends_on arch: :arm64' "formula arm64 constraint"
assert_file_contains "$FORMULA_PATH" 'depends_on macos: :ventura' "formula macOS constraint"
assert_file_contains "$FORMULA_PATH" 'bundle = buildpath/"idocs-darwin-arm64"' "formula detects release bundle directory"
assert_file_contains "$FORMULA_PATH" 'libexec.install bundle.children' "formula installs bundled binary and frameworks together"
assert_file_contains "$FORMULA_PATH" 'libexec.install Dir["*"]' "formula supports stripped archive layout"
assert_file_contains "$FORMULA_PATH" 'bin.write_exec_script libexec/"idocs"' "formula wrapper"
assert_file_contains "$FORMULA_PATH" 'system "#{bin}/idocs", "--version"' "formula test command"
assert_contains "$(cat "$TMP_GIT_LOG")" "git -C $TMP_TAP_DIR add Formula/idocs.rb" "formula should be staged"
assert_contains "$(cat "$TMP_GIT_LOG")" "git -C $TMP_TAP_DIR commit -m Update idocs Homebrew formula to v1.2.3" "formula should be committed"
assert_contains "$(cat "$TMP_GIT_LOG")" "git -C $TMP_TAP_DIR push origin main" "formula should be pushed"

echo "[TEST] publish script skips commit and push when formula is unchanged"
TMP_PACKAGE_DIR="$(new_tmp_dir)"
TMP_TAP_DIR="$(new_tmp_dir)"
TMP_CHECKSUM_FILE="$(new_tmp_dir)/idocs-darwin-arm64.sha256"
TMP_BIN_DIR="$(new_tmp_dir)"
TMP_GIT_LOG="$(new_tmp_dir)/git.log"
write_package_json "$TMP_PACKAGE_DIR"
TEST_SHA256="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
printf '%s  idocs-darwin-arm64.tar.gz\n' "$TEST_SHA256" > "$TMP_CHECKSUM_FILE"
write_git_stub "$TMP_BIN_DIR" "$TMP_GIT_LOG"

run_cmd_capture env \
  PATH="$TMP_BIN_DIR:$PATH" \
  GIT_STUB_LOG="$TMP_GIT_LOG" \
  HOMEBREW_TAP_LOCAL_PATH="$TMP_TAP_DIR" \
  IDOCS_NPM_PACKAGE_DIR="$TMP_PACKAGE_DIR" \
  IDOCS_HOMEBREW_CHECKSUM_FILE="$TMP_CHECKSUM_FILE" \
  bash "$SCRIPT_PATH"
assert_exit_zero "$RUN_CODE" "publish-homebrew-formula unchanged setup"
: > "$TMP_GIT_LOG"

run_cmd_capture env \
  PATH="$TMP_BIN_DIR:$PATH" \
  GIT_STUB_LOG="$TMP_GIT_LOG" \
  HOMEBREW_TAP_LOCAL_PATH="$TMP_TAP_DIR" \
  IDOCS_NPM_PACKAGE_DIR="$TMP_PACKAGE_DIR" \
  IDOCS_HOMEBREW_CHECKSUM_FILE="$TMP_CHECKSUM_FILE" \
  bash "$SCRIPT_PATH"
assert_exit_zero "$RUN_CODE" "publish-homebrew-formula unchanged skip"
assert_contains "$RUN_OUTPUT" "Formula unchanged; skipping Homebrew tap commit." "unchanged formula skip message"
if [[ "$(cat "$TMP_GIT_LOG")" == *" commit "* || "$(cat "$TMP_GIT_LOG")" == *" push "* ]]; then
  echo "[FAIL] unchanged formula should not commit or push" >&2
  cat "$TMP_GIT_LOG" >&2
  exit 1
fi

echo "[PASS] publish-homebrew-formula checks completed."
