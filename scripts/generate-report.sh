#!/bin/bash

BIN_PATH=$(swift build --show-bin-path)
PROF_DATA="$BIN_PATH/codecov/default.profdata"
TEST_BIN="$BIN_PATH/iDocsPackageTests.xctest/Contents/MacOS/iDocsPackageTests"
OUTPUT_DIR="coverage_report"

if [ ! -f "$PROF_DATA" ]; then
    echo "Error: Profile data not found. Run 'swift test --enable-code-coverage' first."
    exit 1
fi

echo "Generating HTML coverage report in $OUTPUT_DIR..."
mkdir -p "$OUTPUT_DIR"

xcrun llvm-cov show "$TEST_BIN" \
  -instr-profile="$PROF_DATA" \
  -format=html \
  -output-dir="$OUTPUT_DIR" \
  -ignore-filename-regex=".build|Tests"

echo "Report generated. Open $OUTPUT_DIR/index.html to view."
