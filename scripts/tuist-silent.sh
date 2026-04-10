#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
DERIVED_DATA_PATH="${IDOCS_DERIVED_DATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData/iDocs-codex}"

search_file() {
  local pattern="$1"
  local file="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" "$file"
  else
    grep -n -E "$pattern" "$file"
  fi
}

tuist_safe() {
  local tmp
  tmp="$(mktemp)"

  if "$@" >"$tmp" 2>&1; then
    cat "$tmp"
    rm -f "$tmp"
    return 0
  fi

  if search_file "recent-paths.json" "$tmp" >/dev/null 2>&1; then
    rm -f "$HOME/.local/state/tuist/recent-paths.json"
    mkdir -p "$HOME/.local/state/tuist"
    touch "$HOME/.local/state/tuist/recent-paths.json"
    sleep 1

    if "$@" >"$tmp" 2>&1; then
      cat "$tmp"
      rm -f "$tmp"
      return 0
    fi
  fi

  cat "$tmp" >&2
  rm -f "$tmp"
  return 1
}

ensure_workspace() {
  if [[ -d "iDocs.xcworkspace" ]]; then
    return 0
  fi

  if tuist_safe tuist generate >/dev/null; then
    return 0
  fi

  echo "Error: iDocs.xcworkspace is missing and 'tuist generate' failed." >&2
  return 1
}

run_xcodebuild_silent() {
  local tmp
  tmp="$(mktemp)"

  if xcodebuild -derivedDataPath "$DERIVED_DATA_PATH" "$@" >"$tmp" 2>&1; then
    if ! search_file "^\\*\\* (BUILD|TEST) SUCCEEDED \\*\\*$|^✔ Test run with .* passed.*$" "$tmp" | sed -E 's/^[0-9]+://'; then
      tail -n 20 "$tmp"
    fi
    rm -f "$tmp"
    return 0
  fi

  echo "xcodebuild failed; showing failure details:" >&2
  # Search for common failure patterns and show surrounding context
  if grep -E "✘|error:|fail:|failed" "$tmp" >/dev/null 2>&1; then
     grep -B 2 -A 10 -E "✘|error:|fail:|failed" "$tmp" | head -n 100 >&2
  else
     tail -n 120 "$tmp" >&2
  fi
  
  rm -f "$tmp"
  return 1
}

usage() {
  cat <<'EOF'
Usage:
  ./scripts/tuist-silent.sh build [scheme]
  ./scripts/tuist-silent.sh run [scheme] [args...]
  ./scripts/tuist-silent.sh test [test-target]
  ./scripts/tuist-silent.sh test-all

Defaults:
  scheme = idocs
  test target = iDocsTests

Examples:
  ./scripts/tuist-silent.sh build
  ./scripts/tuist-silent.sh run idocs --help
  ./scripts/tuist-silent.sh test
  ./scripts/tuist-silent.sh test-all
EOF
}

latest_binary() {
  local name="$1"
  if [[ -f "$DERIVED_DATA_PATH/Build/Products/Debug/$name" ]]; then
    echo "$DERIVED_DATA_PATH/Build/Products/Debug/$name"
    return 0
  fi
  find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/Debug/$name" -type f 2>/dev/null | head -n 1
}

resolve_target() {
  local input="$1"
  case "$input" in
    idocs|iDocs)
      echo "iDocs:idocs"
      ;;
    *)
      echo "$input:$input"
      ;;
  esac
}

build_quiet() {
  local target_scheme="$1"
  ensure_workspace
  run_xcodebuild_silent \
    build \
    -workspace iDocs.xcworkspace \
    -scheme "$target_scheme" \
    -destination "platform=macOS,arch=arm64"
}

cmd="${1:-}"
scheme="${2:-idocs}"

case "$cmd" in
  build)
    IFS=':' read -r target_scheme _ <<<"$(resolve_target "$scheme")"
    build_quiet "$target_scheme"
    ;;
  run)
    shift || true
    scheme="${1:-idocs}"
    shift || true
    IFS=':' read -r target_scheme binary_name <<<"$(resolve_target "$scheme")"
    build_quiet "$target_scheme" >/dev/null
    bin="$(latest_binary "$binary_name")"
    if [[ -z "$bin" ]]; then
      echo "Error: built binary not found for scheme '$scheme'" >&2
      exit 1
    fi
    "$bin" "$@"
    ;;
  test)
    test_target="${2:-iDocsTests}"
    case "$test_target" in
      iDocsTests)
        test_scheme="iDocs"
        ;;
      *)
        echo "Error: unsupported test target '$test_target' (supported: iDocsTests)" >&2
        exit 1
        ;;
    esac
    ensure_workspace
    rm -rf /var/tmp/test-session-systemlogs-*.logarchive 2>/dev/null || true
    run_xcodebuild_silent \
      test \
      -workspace iDocs.xcworkspace \
      -scheme "$test_scheme" \
      -destination "platform=macOS,arch=arm64" \
      -parallel-testing-enabled NO \
      -only-testing:"$test_target" \
      GITHUB_WORKSPACE="${GITHUB_WORKSPACE:-}" \
      IDOCS_PROJECT_ROOT="${IDOCS_PROJECT_ROOT:-}" \
      IDOCS_LOCAL_BINARY="${IDOCS_LOCAL_BINARY:-}"
    ;;
  test-all)
    "$0" test iDocsTests
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
