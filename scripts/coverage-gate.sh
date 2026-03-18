#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

THRESHOLD="${1:-80}"
WORKSPACE="${IDOCS_WORKSPACE:-iDocs.xcworkspace}"
SCHEME="${IDOCS_SCHEME:-iDocs}"
DESTINATION="${IDOCS_DESTINATION:-platform=macOS,arch=arm64}"
TEST_TARGET="${IDOCS_TEST_TARGET:-iDocsTests}"
RESULT_BUNDLE="${IDOCS_COVERAGE_RESULT_BUNDLE:-/tmp/idocs-coverage.xcresult}"
LOG_FILE="${IDOCS_COVERAGE_LOG:-/tmp/idocs-coverage.log}"

if [[ ! -d "$WORKSPACE" ]]; then
  echo "Workspace missing: $WORKSPACE. Trying 'tuist generate'..."
  tuist generate >/dev/null
fi

rm -rf "$RESULT_BUNDLE"

if ! xcodebuild test \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -only-testing:"$TEST_TARGET" \
  -enableCodeCoverage YES \
  -resultBundlePath "$RESULT_BUNDLE" >"$LOG_FILE" 2>&1; then
  echo "Coverage run failed. Recent output:"
  tail -n 120 "$LOG_FILE"
  exit 1
fi

if [[ ! -d "$RESULT_BUNDLE" ]]; then
  echo "Coverage result bundle not found: $RESULT_BUNDLE"
  exit 1
fi

report_json="$(xcrun xccov view --report --json "$RESULT_BUNDLE")"

overall_pct="$(
  jq -r '
    [
      .targets[]
      | select(
          (.name | startswith("iDocsKit"))
          or (.name | startswith("iDocsAdapter"))
          or (.name == "libiDocsApp.a")
        )
      | .lineCoverage
    ] as $cov
    | if ($cov | length) == 0 then
        0
      else
        (($cov | add) / ($cov | length) * 100)
      end
  ' <<<"$report_json"
)"

echo "Coverage summary (line %):"
jq -r '
  .targets[]
  | select(
      (.name | startswith("iDocsKit"))
      or (.name | startswith("iDocsAdapter"))
      or (.name == "libiDocsApp.a")
    )
  | "  - \(.name): \((.lineCoverage * 100) | floor)%"
' <<<"$report_json"

overall_int="$(printf "%.0f" "$overall_pct")"
echo "Average core target coverage: ${overall_int}% (threshold: ${THRESHOLD}%)"

if (( overall_int < THRESHOLD )); then
  echo "Error: Coverage is below threshold."
  exit 1
fi

echo "Coverage gate passed."
