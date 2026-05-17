#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="${IDOCS_NPM_PACKAGE_DIR:-$ROOT_DIR/npm}"
TAP_REPOSITORY="${HOMEBREW_TAP_REPOSITORY:-RbBtSn0w/homebrew-tap}"
TAP_BRANCH="${HOMEBREW_TAP_BRANCH:-main}"
ASSET_NAME="idocs-darwin-arm64.tar.gz"
CHECKSUM_ASSET_NAME="idocs-darwin-arm64.sha256"
VERSION="${1:-$(node -p "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8')).version" "$PACKAGE_DIR/package.json")}"
DEFAULT_RELEASE_BASE_URL='https://github.com/RbBtSn0w/Apple-iDocs/releases/download/v{version}'
RELEASE_BASE_URL="${IDOCS_HOMEBREW_RELEASE_BASE_URL:-$DEFAULT_RELEASE_BASE_URL}"
RELEASE_BASE_URL="${RELEASE_BASE_URL//\{version\}/$VERSION}"
ASSET_URL="$RELEASE_BASE_URL/$ASSET_NAME"
CHECKSUM_URL="$RELEASE_BASE_URL/$CHECKSUM_ASSET_NAME"
TMP_DIRS=()

cleanup() {
  for d in "${TMP_DIRS[@]:-}"; do
    rm -rf "$d" 2>/dev/null || true
  done
}
trap cleanup EXIT

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

new_tmp_dir() {
  local d
  d="$(mktemp -d)"
  TMP_DIRS+=("$d")
  echo "$d"
}

if [[ "$TAP_REPOSITORY" != */* ]]; then
  fail "HOMEBREW_TAP_REPOSITORY must use owner/repo format; got '$TAP_REPOSITORY'."
fi

read_checksum() {
  local checksum_file="${IDOCS_HOMEBREW_CHECKSUM_FILE:-}"
  local checksum_text=""
  local checksum=""

  if [[ -n "${IDOCS_HOMEBREW_SHA256:-}" ]]; then
    checksum="$IDOCS_HOMEBREW_SHA256"
  else
    if [[ -z "$checksum_file" ]]; then
      checksum_file="$(new_tmp_dir)/$CHECKSUM_ASSET_NAME"
      curl -fsSL --retry 3 --retry-connrefused "$CHECKSUM_URL" -o "$checksum_file"
    fi

    if [[ ! -f "$checksum_file" ]]; then
      fail "Checksum file not found at $checksum_file."
    fi

    checksum_text="$(cat "$checksum_file")"
    checksum="$(printf '%s\n' "$checksum_text" | awk 'NF { print $1; exit }')"
  fi

  if [[ ! "$checksum" =~ ^[0-9a-fA-F]{64}$ ]]; then
    fail "Invalid SHA-256 checksum for $ASSET_NAME: '$checksum'."
  fi

  printf '%s\n' "$checksum" | tr '[:upper:]' '[:lower:]'
}

prepare_tap_checkout() {
  local tap_dir="${HOMEBREW_TAP_LOCAL_PATH:-}"

  if [[ -n "$tap_dir" ]]; then
    mkdir -p "$tap_dir"
    printf '%s\n' "$tap_dir"
    return
  fi

  if [[ -z "${HOMEBREW_TAP_TOKEN:-}" ]]; then
    fail "HOMEBREW_TAP_TOKEN is required to publish to $TAP_REPOSITORY."
  fi

  tap_dir="$(new_tmp_dir)/homebrew-tap"
  git clone \
    --branch "$TAP_BRANCH" \
    --depth 1 \
    "https://x-access-token:${HOMEBREW_TAP_TOKEN}@github.com/${TAP_REPOSITORY}.git" \
    "$tap_dir"
  printf '%s\n' "$tap_dir"
}

write_formula() {
  local destination="$1"
  local checksum="$2"

  cat >"$destination" <<FORMULA
class Idocs < Formula
  desc "Swift-native Apple documentation CLI"
  homepage "https://github.com/RbBtSn0w/Apple-iDocs"
  url "$ASSET_URL"
  version "$VERSION"
  sha256 "$checksum"
  license "MIT"

  depends_on macos: :ventura
  depends_on arch: :arm64

  def install
    bundle = buildpath/"idocs-darwin-arm64"
    if bundle.directory?
      libexec.install bundle.children
    else
      libexec.install Dir["*"]
    end
    bin.write_exec_script libexec/"idocs"
  end

  test do
    system "#{bin}/idocs", "--version"
  end
end
FORMULA
}

SHA256="$(read_checksum)"
TAP_DIR="$(prepare_tap_checkout)"
FORMULA_DIR="$TAP_DIR/Formula"
FORMULA_PATH="$FORMULA_DIR/idocs.rb"
NEXT_FORMULA="$(new_tmp_dir)/idocs.rb"

mkdir -p "$FORMULA_DIR"
write_formula "$NEXT_FORMULA" "$SHA256"

if [[ -f "$FORMULA_PATH" ]] && cmp -s "$NEXT_FORMULA" "$FORMULA_PATH"; then
  echo "Formula unchanged; skipping Homebrew tap commit."
  exit 0
fi

cp "$NEXT_FORMULA" "$FORMULA_PATH"

git -C "$TAP_DIR" config user.name "${HOMEBREW_TAP_GIT_NAME:-github-actions[bot]}"
git -C "$TAP_DIR" config user.email "${HOMEBREW_TAP_GIT_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
git -C "$TAP_DIR" add Formula/idocs.rb
git -C "$TAP_DIR" commit -m "Update idocs Homebrew formula to v$VERSION"
git -C "$TAP_DIR" push origin "$TAP_BRANCH"

echo "Published idocs v$VERSION Homebrew formula to $TAP_REPOSITORY."
