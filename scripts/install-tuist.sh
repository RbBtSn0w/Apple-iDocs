#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-$(< .tuist-version)}"
INSTALL_ROOT="${IDOCS_TUIST_ROOT:-$ROOT_DIR/.tools/tuist}"
VERSION_DIR="$INSTALL_ROOT/$VERSION"
BIN_DIR="$INSTALL_ROOT/bin"
ARCHIVE_PATH="$INSTALL_ROOT/tuist-$VERSION.zip"

mkdir -p "$VERSION_DIR" "$BIN_DIR"

installed_version() {
  if [[ -x "$VERSION_DIR/tuist" ]]; then
    "$VERSION_DIR/tuist" version 2>/dev/null | tr -d '[:space:]' || true
  fi
}

if [[ ! -x "$VERSION_DIR/tuist" || "$(installed_version)" != "$VERSION" ]]; then
  curl -fsSL "https://github.com/tuist/tuist/releases/download/${VERSION}/tuist.zip" -o "$ARCHIVE_PATH"
  rm -rf "$VERSION_DIR"/*
  unzip -q "$ARCHIVE_PATH" -d "$VERSION_DIR"
  chmod +x "$VERSION_DIR/tuist"
fi

if [[ "$(installed_version)" != "$VERSION" ]]; then
  echo "Error: installed Tuist version does not match $VERSION" >&2
  exit 1
fi

ln -sf "../$VERSION/tuist" "$BIN_DIR/tuist"
echo "$BIN_DIR"
