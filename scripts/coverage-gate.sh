#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

THRESHOLD="${1:-80}"
WORKSPACE="${IDOCS_WORKSPACE:-iDocs.xcworkspace}"
SCHEME="${IDOCS_SCHEME:-iDocs}"
DESTINATION="${IDOCS_DESTINATION:-platform=macOS,arch=arm64}"
TEST_TARGET="${IDOCS_TEST_TARGET:-}"
TEST_TARGETS_RAW="${IDOCS_TEST_TARGETS:-}"
RESULT_BUNDLE="${IDOCS_COVERAGE_RESULT_BUNDLE:-/tmp/idocs-coverage.xcresult}"
LOG_FILE="${IDOCS_COVERAGE_LOG:-/tmp/idocs-coverage.log}"
DERIVED_DATA_PATH="${IDOCS_COVERAGE_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/iDocs-codex-coverage}"

if [[ ! -d "$WORKSPACE" ]]; then
  echo "Workspace missing: $WORKSPACE. Trying 'tuist generate'..."
  tuist generate >/dev/null
fi

rm -rf "$RESULT_BUNDLE"
rm -rf /var/tmp/test-session-systemlogs-*.logarchive 2>/dev/null || true

declare -a test_targets
if [[ -n "$TEST_TARGETS_RAW" ]]; then
  read -r -a test_targets <<<"$TEST_TARGETS_RAW"
elif [[ -n "$TEST_TARGET" ]]; then
  test_targets=("$TEST_TARGET")
else
  # Coverage is averaged across iDocsKit, iDocsAdapter, and iDocsApp, so the
  # default run must execute both test bundles that exercise those modules.
  test_targets=("iDocsTests" "iDocsAdapterTests")
fi

coverage_scheme_for_target() {
  case "$1" in
    iDocsTests)
      echo "$SCHEME"
      ;;
    iDocsAdapterTests)
      echo "iDocsAdapter"
      ;;
    *)
      return 1
      ;;
  esac
}

RESULT_BUNDLE_ROOT="${RESULT_BUNDLE%.xcresult}"
LOG_FILE_ROOT="${LOG_FILE%.log}"
declare -a merge_inputs

for target in "${test_targets[@]}"; do
  scheme_for_target="$(coverage_scheme_for_target "$target")" || {
    echo "Unsupported coverage test target: $target" >&2
    exit 1
  }

  result_bundle_path="${RESULT_BUNDLE_ROOT}-${target}.xcresult"
  log_file_path="${LOG_FILE_ROOT}-${target}.log"
  export_dir_path="${RESULT_BUNDLE_ROOT}-${target}-coverage"

  rm -rf "$result_bundle_path" "$export_dir_path"

  if ! xcodebuild test \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -workspace "$WORKSPACE" \
    -scheme "$scheme_for_target" \
    -destination "$DESTINATION" \
    -only-testing:"$target" \
    -parallel-testing-enabled NO \
    -enableCodeCoverage YES \
    -resultBundlePath "$result_bundle_path" >"$log_file_path" 2>&1; then
    echo "Coverage run failed for $target. Recent output:"
    tail -n 120 "$log_file_path"
    exit 1
  fi

  if [[ ! -d "$result_bundle_path" ]]; then
    echo "Coverage result bundle not found: $result_bundle_path"
    exit 1
  fi

  xcrun xcresulttool export coverage --path "$result_bundle_path" --output-path "$export_dir_path" >/dev/null

  coverage_report_path="$(find "$export_dir_path" -maxdepth 1 -name '*CoverageReport' -print -quit)"
  coverage_archive_path="$(find "$export_dir_path" -maxdepth 1 -name '*CoverageArchive' -print -quit)"

  if [[ -z "$coverage_report_path" || -z "$coverage_archive_path" ]]; then
    echo "Coverage artifacts missing for $target under $export_dir_path"
    exit 1
  fi

  merge_inputs+=("$coverage_report_path" "$coverage_archive_path")
done

if (( ${#merge_inputs[@]} == 2 )); then
  report_json="$(xcrun xccov view --json "${merge_inputs[0]}")"
else
  merged_report_path="${RESULT_BUNDLE_ROOT}-merged.xccovreport"
  merged_archive_path="${RESULT_BUNDLE_ROOT}-merged.xccovarchive"
  rm -rf "$merged_report_path" "$merged_archive_path"
  xcrun xccov merge --outReport "$merged_report_path" --outArchive "$merged_archive_path" "${merge_inputs[@]}" >/dev/null
  report_json="$(xcrun xccov view --json "$merged_report_path")"
fi

overall_pct="$(
  jq -r '
    [
      .targets[]
      | select(
          (.name == "iDocsKit.framework")
          or (.name == "iDocsAdapter.framework")
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
      (.name == "iDocsKit.framework")
      or (.name == "iDocsAdapter.framework")
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
