#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"
source scripts/benchmark/common.sh

TARGET_ID="${1:-all}"
CACHE_DIR="${2:-specs/008-mcp-service-benchmark/artifacts/cache}"

log "reset target state: ${TARGET_ID}"
ensure_dir "$CACHE_DIR"
rm -rf "${CACHE_DIR:?}"/*

kill_if_running() {
  local pattern="$1"
  if pgrep -f "$pattern" >/dev/null 2>&1; then
    pkill -f "$pattern" || true
  fi
}

case "$TARGET_ID" in
  idocs-cli)
    kill_if_running "idocs"
    ;;
  apple-docs-mcp)
    kill_if_running "apple-docs-mcp"
    ;;
  apple-doc-mcp)
    kill_if_running "apple-doc-mcp"
    ;;
  sosumi-ai)
    kill_if_running "sosumi"
    ;;
  all)
    kill_if_running "idocs"
    kill_if_running "apple-docs-mcp"
    kill_if_running "apple-doc-mcp"
    kill_if_running "sosumi"
    ;;
  *)
    log "unknown target: ${TARGET_ID}"
    ;;
esac

log "reset complete"
