#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"
source scripts/benchmark/common.sh

PROBES_FILE="specs/008-mcp-service-benchmark/fixtures/minimum-probes.json"
OUTPUT_DIR="specs/008-mcp-service-benchmark/artifacts/results"
OUTPUT_FILE="${OUTPUT_DIR}/target-probes.json"
ensure_dir "$OUTPUT_DIR"

python3 - "$PROBES_FILE" "$OUTPUT_FILE" <<'PY'
import json, subprocess, sys, time
probes_file, output_file = sys.argv[1], sys.argv[2]
script_map = {
    "idocs": "./scripts/benchmark/target-idocs.sh",
    "apple-docs-mcp": "./scripts/benchmark/target-apple-docs-mcp.sh",
    "apple-doc-mcp": "./scripts/benchmark/target-apple-doc-mcp.sh",
    "sosumi-ai": "./scripts/benchmark/target-sosumi-ai.sh",
}
with open(probes_file, "r", encoding="utf-8") as f:
    probes = json.load(f)["probes"]

records = []
for probe in probes:
    target = probe["targetId"]
    start = time.time()
    proc = subprocess.run([script_map[target], "--probe"], capture_output=True, text=True)
    elapsed = int((time.time() - start) * 1000)
    status = "success" if proc.returncode == 0 else "failure"
    records.append({
        "targetId": target,
        "request": probe["request"],
        "status": status,
        "durationMs": elapsed,
        "callCount": 1,
        "rawEvidenceRef": f"artifacts/evidence/probe-{target}.json",
        "raw": proc.stdout.strip() or proc.stderr.strip()
    })

with open(output_file, "w", encoding="utf-8") as f:
    json.dump({"records": records}, f, ensure_ascii=False, indent=2)
PY

log "probe results written to ${OUTPUT_FILE}"
