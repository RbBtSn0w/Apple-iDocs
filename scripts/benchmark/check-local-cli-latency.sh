#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

source scripts/benchmark/common.sh

DERIVED_DATA_PATH="${IDOCS_DERIVED_DATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData/iDocs-codex}"
SAMPLES="${IDOCS_LATENCY_SAMPLES:-5}"
KEEP_ARTIFACTS="${IDOCS_LATENCY_KEEP_ARTIFACTS:-0}"
COMMAND_TIMEOUT="${IDOCS_LATENCY_COMMAND_TIMEOUT_SECONDS:-25}"
WORK_DIR="${IDOCS_LATENCY_WORK_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/idocs-latency-gate.XXXXXX")}"
CACHE_DIR="${IDOCS_LATENCY_CACHE_DIR:-$WORK_DIR/cache}"
USAGE_LOG="${IDOCS_LATENCY_USAGE_LOG:-$WORK_DIR/usage.jsonl}"

cleanup() {
  if [[ "$KEEP_ARTIFACTS" == "1" ]]; then
    return
  fi

  if [[ -n "${IDOCS_LATENCY_WORK_DIR:-}" || -n "${IDOCS_LATENCY_CACHE_DIR:-}" || -n "${IDOCS_LATENCY_USAGE_LOG:-}" ]]; then
    return
  fi

  rm -rf "$WORK_DIR"
}

find_local_binary() {
  local candidate

  for candidate in \
    "${IDOCS_LOCAL_BINARY:-}" \
    "$DERIVED_DATA_PATH/Build/Products/Debug/idocs" \
    "$ROOT_DIR/.build/debug/idocs" \
    "$ROOT_DIR/.build/release/idocs"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/Debug/idocs" -type f 2>/dev/null | head -n 1
}

build_local_binary() {
  log "build local idocs binary"
  ./scripts/tuist-silent.sh build iDocs >/dev/null
}

resolve_binary() {
  local binary
  binary="$(find_local_binary)"
  if [[ -z "$binary" ]]; then
    build_local_binary
    binary="$(find_local_binary)"
  fi

  if [[ -z "$binary" || ! -x "$binary" ]]; then
    echo "Error: unable to resolve a local idocs binary" >&2
    exit 1
  fi

  echo "$binary"
}

run_cli() {
  /usr/bin/python3 - "$IDOCS_BINARY" "$COMMAND_TIMEOUT" "$CACHE_DIR" "$USAGE_LOG" "$@" <<'PY'
import os
import subprocess
import sys

binary = sys.argv[1]
timeout = float(sys.argv[2])
cache_dir = sys.argv[3]
usage_log = sys.argv[4]
command = [binary] + sys.argv[5:]

environment = os.environ.copy()
environment["IDOCS_CACHE_PATH"] = cache_dir
environment["IDOCS_USAGE_LOG_PATH"] = usage_log

try:
    result = subprocess.run(
        command,
        env=environment,
        stdout=subprocess.DEVNULL,
        timeout=timeout,
        check=False,
    )
except subprocess.TimeoutExpired:
    print(
        f"Error: command timed out after {timeout:.1f}s: {' '.join(command)}",
        file=sys.stderr,
    )
    sys.exit(124)

sys.exit(result.returncode)
PY
}

prepare_workspace() {
  rm -rf "$CACHE_DIR"
  rm -f "$USAGE_LOG"
  mkdir -p "$CACHE_DIR"
}

run_samples() {
  local index

  log "warm fetch cache"
  run_cli fetch "/documentation/swiftui/view" --json --caller "latency.fetch.warmup"

  for index in $(seq 1 "$SAMPLES"); do
    log "sample ${index}/${SAMPLES}: module search"
    run_cli search "SwiftUI" --json --caller "latency.module"

    log "sample ${index}/${SAMPLES}: composite search"
    run_cli search "SwiftUI View" --json --caller "latency.composite"

    log "sample ${index}/${SAMPLES}: no-result search"
    run_cli search "qwertyzzdocnotfound" --json --caller "latency.noresult"

    log "sample ${index}/${SAMPLES}: cached fetch"
    run_cli fetch "/documentation/swiftui/view" --json --caller "latency.fetch"
  done
}

main() {
  trap cleanup EXIT

  if ! [[ "$SAMPLES" =~ ^[0-9]+$ ]] || [[ "$SAMPLES" -lt 1 ]]; then
    echo "Error: IDOCS_LATENCY_SAMPLES must be an integer >= 1" >&2
    exit 1
  fi

  IDOCS_BINARY="$(resolve_binary)"
  export IDOCS_BINARY

  prepare_workspace
  log "using binary: $IDOCS_BINARY"
  log "usage log: $USAGE_LOG"
  log "command timeout: ${COMMAND_TIMEOUT}s"
  run_samples

  swift scripts/benchmark/evaluate-cli-latency.swift "$USAGE_LOG" --min-samples "$SAMPLES"

  if [[ "$KEEP_ARTIFACTS" == "1" ]]; then
    log "artifacts retained at $WORK_DIR"
  fi
}

main "$@"
