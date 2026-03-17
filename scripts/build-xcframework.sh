#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUTPUT_DIR="$ROOT_DIR/Derived/XCFrameworks"
ARCHIVE_DIR="$ROOT_DIR/Derived/Archives"
rm -rf "$OUTPUT_DIR" "$ARCHIVE_DIR"
mkdir -p "$OUTPUT_DIR" "$ARCHIVE_DIR"

build_archive() {
  local scheme="$1"
  local archive_path="$ARCHIVE_DIR/${scheme}.xcarchive"
  xcodebuild archive \
    -workspace "$ROOT_DIR/iDocs.xcworkspace" \
    -scheme "$scheme" \
    -destination "generic/platform=macOS" \
    -archivePath "$archive_path" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES
}

create_xcframework() {
  local scheme="$1"
  local archive_path="$ARCHIVE_DIR/${scheme}.xcarchive"
  xcodebuild -create-xcframework \
    -framework "$archive_path/Products/Library/Frameworks/${scheme}.framework" \
    -output "$OUTPUT_DIR/${scheme}.xcframework"
}

build_archive "iDocsKit"
create_xcframework "iDocsKit"

build_archive "iDocsAdapter"
create_xcframework "iDocsAdapter"

echo "Built XCFrameworks under: $OUTPUT_DIR"
