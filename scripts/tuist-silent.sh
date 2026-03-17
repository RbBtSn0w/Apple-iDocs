#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

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
  tuist generate >/dev/null
  tuist xcodebuild build -workspace iDocs.xcworkspace -scheme "$target_scheme" -quiet
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
    tuist generate >/dev/null
    tuist xcodebuild test \
      -workspace iDocs.xcworkspace \
      -scheme "$test_scheme" \
      -destination "platform=macOS" \
      -only-testing:"$test_target" \
      -quiet
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
