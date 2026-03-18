#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-$(node -p "JSON.parse(require('fs').readFileSync('npm/package.json','utf8')).version")}"
OUTPUT_DIR="${2:-$ROOT_DIR/dist/release/v$VERSION}"
DERIVED_DATA_PATH="${IDOCS_RELEASE_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/iDocs-release}"
BUILD_LOG="${IDOCS_RELEASE_BUILD_LOG:-/tmp/idocs-release-build.log}"
ASSET_NAME="idocs-darwin-arm64.tar.gz"
BUNDLE_DIR="$OUTPUT_DIR/idocs-darwin-arm64"

mkdir -p "$OUTPUT_DIR"

if [[ ! -d "iDocs.xcworkspace" ]]; then
  tuist generate >/dev/null
fi

xcodebuild build \
  -workspace iDocs.xcworkspace \
  -scheme iDocs \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "$DERIVED_DATA_PATH" >"$BUILD_LOG" 2>&1 || {
  echo "Release build failed. Recent output:" >&2
  tail -n 120 "$BUILD_LOG" >&2
  exit 1
}

BIN="$DERIVED_DATA_PATH/Build/Products/Release/idocs"
if [[ ! -x "$BIN" ]]; then
  echo "Release binary not found at $BIN" >&2
  exit 1
fi

rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Frameworks"
cp "$BIN" "$BUNDLE_DIR/idocs"
chmod +x "$BUNDLE_DIR/idocs"

PRODUCTS_DIR="$DERIVED_DATA_PATH/Build/Products/Release"
for framework in "$PRODUCTS_DIR"/*.framework; do
  [[ -d "$framework" ]] || continue
  cp -R "$framework" "$BUNDLE_DIR/Frameworks/"
done

(
  cd "$OUTPUT_DIR"
  tar -czf "$ASSET_NAME" idocs-darwin-arm64
  shasum -a 256 "$ASSET_NAME" > "${ASSET_NAME%.tar.gz}.sha256"
)

echo "Release artifacts generated:"
echo "  - $OUTPUT_DIR/$ASSET_NAME"
echo "  - $OUTPUT_DIR/${ASSET_NAME%.tar.gz}.sha256"
