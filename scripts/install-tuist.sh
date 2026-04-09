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

if [[ ! -x "$VERSION_DIR/tuist" ]]; then
  curl -fsSL "https://github.com/tuist/tuist/releases/download/${VERSION}/tuist.zip" -o "$ARCHIVE_PATH"
  rm -rf "$VERSION_DIR"/*
  unzip -q "$ARCHIVE_PATH" -d "$VERSION_DIR"
  chmod +x "$VERSION_DIR/tuist"
fi

ln -sf "../$VERSION/tuist" "$BIN_DIR/tuist"
echo "$BIN_DIR"
