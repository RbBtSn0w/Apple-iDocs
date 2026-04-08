#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"
source scripts/benchmark/common.sh

TARGETS_FILE="specs/008-mcp-service-benchmark/fixtures/targets.json"
OUTPUT_FILE=".cursor/mcp.json"

ensure_dir ".cursor"

log "install benchmark runner dependencies"
(cd scripts/benchmark && npm install --no-audit --no-fund >/dev/null)

python3 - "$TARGETS_FILE" "$OUTPUT_FILE" <<'PY'
import json, sys
targets_file, output_file = sys.argv[1], sys.argv[2]
with open(targets_file, "r", encoding="utf-8") as f:
    target_data = json.load(f)
mcp_servers = {}
for target in target_data["targets"]:
    if not target.get("enabled", True):
        continue
    if target.get("kind") != "mcp":
        continue
    if not target.get("command"):
        continue
    mcp_servers[target["id"]] = {
        "command": target["command"],
        "args": target.get("args", [])
    }
payload = {"mcpServers": mcp_servers}
with open(output_file, "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False, indent=2)
PY

log "project-local mcp config written to ${OUTPUT_FILE}"
