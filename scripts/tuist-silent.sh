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
  scheme = iDocs
  test target = iDocsTests

Examples:
  ./scripts/tuist-silent.sh build
  ./scripts/tuist-silent.sh run iDocs --help
  ./scripts/tuist-silent.sh run iDocsMCP --http --port 8080
  ./scripts/tuist-silent.sh test
  ./scripts/tuist-silent.sh test iDocsMCPTests
  ./scripts/tuist-silent.sh test-all
EOF
}

latest_binary() {
  local name="$1"
  find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/Debug/$name" -type f 2>/dev/null | head -n 1
}

build_quiet() {
  local target_scheme="$1"
  tuist generate >/dev/null
  tuist xcodebuild build -workspace iDocs.xcworkspace -scheme "$target_scheme" -quiet
}

cmd="${1:-}"
scheme="${2:-iDocs}"

case "$cmd" in
  build)
    build_quiet "$scheme"
    ;;
  run)
    shift || true
    scheme="${1:-iDocs}"
    shift || true
    build_quiet "$scheme" >/dev/null
    bin="$(latest_binary "$scheme")"
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
      iDocsMCPTests)
        test_scheme="iDocsMCP"
        ;;
      *)
        echo "Error: unsupported test target '$test_target' (supported: iDocsTests, iDocsMCPTests)" >&2
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
    "$0" test iDocsMCPTests
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
