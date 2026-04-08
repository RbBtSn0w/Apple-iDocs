#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"
source scripts/benchmark/common.sh

RUN_ID="${1:-run-$(date +%Y%m%d-%H%M%S)}"
SHARED_LIMIT="${SHARED_LIMIT:-0}"
APPEND_RECORDS="${APPEND_RECORDS:-0}"
SAMPLE_CLASS="${SAMPLE_CLASS:-cold}"
ATTEMPT_INDEX="${ATTEMPT_INDEX:-1}"
TARGET_FILTER="${TARGET_FILTER:-}"
MATRIX_FILE="specs/008-mcp-service-benchmark/fixtures/task-matrix.json"
GOLDEN_FILE="specs/008-mcp-service-benchmark/fixtures/golden-dataset.json"
OUTPUT_DIR="specs/008-mcp-service-benchmark/artifacts/results/${RUN_ID}"
OUTPUT_FILE="${OUTPUT_DIR}/records.jsonl"
NORMALIZED_DIR="specs/008-mcp-service-benchmark/artifacts/normalized/${RUN_ID}"
ASSERTION_DIR="specs/008-mcp-service-benchmark/artifacts/assertions/${RUN_ID}"

ensure_dir "$OUTPUT_DIR"
ensure_dir "$NORMALIZED_DIR"
ensure_dir "$ASSERTION_DIR"

python3 - "$RUN_ID" "$MATRIX_FILE" "$GOLDEN_FILE" "$OUTPUT_FILE" "$SHARED_LIMIT" "$APPEND_RECORDS" "$SAMPLE_CLASS" "$ATTEMPT_INDEX" "$TARGET_FILTER" "$NORMALIZED_DIR" "$ASSERTION_DIR" <<'PY'
import datetime as dt
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

run_id = sys.argv[1]
matrix_file = sys.argv[2]
golden_file = sys.argv[3]
output_file = sys.argv[4]
shared_limit = int(sys.argv[5])
append_records = int(sys.argv[6]) == 1
sample_class = sys.argv[7]
attempt_index = int(sys.argv[8])
target_filter = sys.argv[9].strip()
normalized_dir = Path(sys.argv[10])
assertion_dir = Path(sys.argv[11])

targets = {
    "idocs-cli": "./scripts/benchmark/target-idocs-cli.sh",
    "apple-docs-mcp": "./scripts/benchmark/target-apple-docs-mcp.sh",
    "apple-doc-mcp": "./scripts/benchmark/target-apple-doc-mcp.sh",
    "sosumi-ai": "./scripts/benchmark/target-sosumi-ai.sh",
}

if target_filter:
    filtered = {}
    for target_id in [x.strip() for x in target_filter.split(",") if x.strip()]:
        if target_id in targets:
            filtered[target_id] = targets[target_id]
    targets = filtered

with open(matrix_file, "r", encoding="utf-8") as f:
    shared = json.load(f)["sharedTasks"]
if shared_limit > 0:
    shared = shared[:shared_limit]

with open(golden_file, "r", encoding="utf-8") as f:
    golden_rows = {row["scenarioId"]: row for row in json.load(f)["scenarios"]}

def now():
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

def token_count(text):
    proc = subprocess.run(["node", "scripts/benchmark/tokenize.mjs", text], capture_output=True, text=True)
    if proc.returncode != 0:
        return max(1, len(text) // 4)
    try:
        return int(proc.stdout.strip())
    except ValueError:
        return max(1, len(text) // 4)

def extract_normalized_fields(payload, output_text):
    content = ""
    if isinstance(payload, dict):
        result = payload.get("result")
        if isinstance(result, dict):
            maybe_content = result.get("content")
            if isinstance(maybe_content, list):
                content = "\n".join(str(x.get("text", "")) for x in maybe_content if isinstance(x, dict))
    candidate = content if content else output_text
    urls = re.findall(r"https?://[^\s)>\"]+", candidate)
    doc_paths = re.findall(r"/documentation/[a-zA-Z0-9_./()-]+", candidate)
    title = None
    for line in candidate.splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            title = stripped.lstrip("#").strip()
            break
    if not title:
        m = re.search(r'"title"\s*:\s*"([^"]+)"', candidate)
        if m:
            title = m.group(1)
    signature = None
    m_sig = re.search(r"([A-Za-z_][A-Za-z0-9_]*\([^)]*\))", candidate)
    if m_sig:
        signature = m_sig.group(1)
    params = []
    for p in re.findall(r'"parameters?"\s*:\s*\[([^\]]*)\]', candidate):
        params.append(p[:200])
    platform = None
    for key in ["iOS", "macOS", "watchOS", "tvOS", "visionOS"]:
        if key.lower() in candidate.lower():
            platform = key
            break
    constraints = []
    for word in ["requires", "must", "cannot", "not supported", "deprecated"]:
        if word in candidate.lower():
            constraints.append(word)
    hits = 0
    for val in [title, signature, platform]:
        if val:
            hits += 1
    if urls:
        hits += 1
    if doc_paths:
        hits += 1
    extraction_confidence = round(min(1.0, hits / 5.0), 2)
    extraction_error = None if hits > 0 else "no_structured_fields_extracted"
    return {
        "title": title,
        "path": doc_paths[0] if doc_paths else None,
        "signature": signature,
        "params": params,
        "platform": platform,
        "constraints": constraints,
        "source_url": urls[0] if urls else None,
        "doc_path": doc_paths[0] if doc_paths else None,
        "raw_output": output_text,
        "extraction_confidence": extraction_confidence,
        "extraction_error": extraction_error,
    }

def score_claims(output_text, scenario_id):
    golden = golden_rows.get(scenario_id, {})
    claims = golden.get("atomicClaims", [])
    if not claims:
        return "unverifiable", "partial", 0.5
    correct = 0
    for claim in claims:
        lower = claim.lower()
        if "contains" in lower:
            needle = claim.split("contains", 1)[1].strip().lower()
            if needle and needle in output_text.lower():
                correct += 1
        elif "equals" in lower:
            needle = claim.split("equals", 1)[1].strip().lower()
            if needle and needle in output_text.lower():
                correct += 1
        elif claim.lower() in output_text.lower():
            correct += 1
    rate = correct / len(claims)
    if rate >= 0.8:
        return "correct", "complete", rate
    if rate >= 0.4:
        return "partial", "partial", rate
    return "missing", "incomplete", rate

def score_required_slots(output_text, scenario_id):
    golden = golden_rows.get(scenario_id, {})
    slots = golden.get("requiredSlots", [])
    if not slots:
        return 0.5
    lower_text = output_text.lower()
    hits = 0
    for slot in slots:
        slot_lower = slot.lower()
        if slot_lower in lower_text:
            hits += 1
            continue
        parts = [p for p in slot_lower.replace("-", "_").split("_") if p]
        if parts and any(part in lower_text for part in parts):
            hits += 1
    return hits / len(slots)

def breakdown_claims(output_text, scenario_id):
    golden = golden_rows.get(scenario_id, {})
    claims = golden.get("atomicClaims", [])
    result = {"correct": 0, "incorrect": 0, "missing": 0, "unverifiable": 0}
    if not claims:
        result["unverifiable"] = 1
        return result
    low = output_text.lower()
    for claim in claims:
        c = claim.lower().strip()
        if not c:
            result["unverifiable"] += 1
            continue
        if "contains" in c:
            needle = c.split("contains", 1)[1].strip()
            if needle in low:
                result["correct"] += 1
            else:
                result["missing"] += 1
        elif "equals" in c:
            needle = c.split("equals", 1)[1].strip()
            if needle in low:
                result["correct"] += 1
            else:
                result["incorrect"] += 1
        elif c in low:
            result["correct"] += 1
        else:
            result["missing"] += 1
    return result

def breakdown_slots(output_text, scenario_id):
    golden = golden_rows.get(scenario_id, {})
    slots = golden.get("requiredSlots", [])
    result = {"hit": 0, "missing": 0}
    if not slots:
        return result
    low = output_text.lower()
    for slot in slots:
        s = slot.lower().strip()
        parts = [p for p in s.replace("-", "_").split("_") if p]
        if s in low or any(p in low for p in parts):
            result["hit"] += 1
        else:
            result["missing"] += 1
    return result

def format_scores(output_text, task_type):
    text_len = len(output_text)
    extractability = 5 if any(k in output_text.lower() for k in ["title", "url", "path", "source"]) else 3
    density = 5 if text_len < 2400 else 3 if text_len < 8000 else 1
    task_fit = 5 if task_type in output_text.lower() else 3
    noise = 5 if output_text.count("\n") < 80 else 3 if output_text.count("\n") < 180 else 1
    citability = 5 if "http" in output_text.lower() or "/documentation/" in output_text.lower() else 3
    return extractability, density, task_fit, noise, citability

def llm_judge(rule_verdict, claim_rate, slot_rate, output_text):
    ambiguous_claim = 0.45 <= claim_rate <= 0.8
    ambiguous_slot = 0.45 <= slot_rate <= 0.8
    trigger = rule_verdict in ("unverifiable", "partial") or ambiguous_claim or ambiguous_slot
    if not trigger:
        return {"triggered": False, "from_llm": False, "judge_verdict": rule_verdict, "judge_confidence": 1.0, "judge_reason": "rule_engine_high_confidence"}

    cmd = os.environ.get("LLM_JUDGE_CMD", "").strip()
    if not cmd:
        return {"triggered": True, "from_llm": False, "judge_verdict": rule_verdict, "judge_confidence": 0.8, "judge_reason": "llm_judge_not_configured_fallback_to_rule"}

    request = {
        "rule_verdict": rule_verdict,
        "claim_rate": claim_rate,
        "slot_rate": slot_rate,
        "output_excerpt": output_text[:3000],
    }
    proc = subprocess.run(cmd, input=json.dumps(request), capture_output=True, text=True, shell=True)
    if proc.returncode != 0:
        return {"triggered": True, "from_llm": False, "judge_verdict": rule_verdict, "judge_confidence": 0.7, "judge_reason": f"llm_judge_failed:{proc.stderr.strip()[:120]}"}
    try:
        payload = json.loads(proc.stdout.strip())
    except Exception:
        return {"triggered": True, "from_llm": False, "judge_verdict": rule_verdict, "judge_confidence": 0.7, "judge_reason": "llm_judge_invalid_json_fallback"}
    return {
        "triggered": True,
        "from_llm": True,
        "judge_verdict": payload.get("judge_verdict", rule_verdict),
        "judge_confidence": float(payload.get("judge_confidence", 0.5)),
        "judge_reason": payload.get("judge_reason", "llm_judge_no_reason"),
    }

mode = "a" if append_records else "w"
with open(output_file, mode, encoding="utf-8") as out:
    for target, cmd in targets.items():
        for task in shared:
            started = now()
            t0 = time.time()
            proc = subprocess.run([cmd, "run", task["input"]], capture_output=True, text=True)
            elapsed = int((time.time() - t0) * 1000)
            finished = now()

            raw = proc.stdout.strip() or proc.stderr.strip()
            try:
                payload = json.loads(raw) if raw else {}
            except json.JSONDecodeError:
                payload = {"status": "failure", "error": raw}

            status = payload.get("status", "failure")
            output_text = json.dumps(payload.get("result", payload), ensure_ascii=False)
            output_len = len(output_text)
            tokens = token_count(output_text)
            call_count = 1
            accuracy_verdict, completeness_verdict, claim_rate = score_claims(output_text, task["scenarioId"])
            slot_rate = score_required_slots(output_text, task["scenarioId"])
            claim_breakdown = breakdown_claims(output_text, task["scenarioId"])
            slot_breakdown = breakdown_slots(output_text, task["scenarioId"])
            format_extractability, format_density, format_task_fit, format_noise, format_citability = format_scores(output_text, task["type"])
            overfetch_flag = output_len > 10000 or output_text.count("http") > 8
            normalized = extract_normalized_fields(payload, output_text)

            normalized_name = f"{target}-{task['scenarioId']}-a{attempt_index}-{sample_class}.json"
            normalized_abs = normalized_dir / normalized_name
            with open(normalized_abs, "w", encoding="utf-8") as f:
                json.dump(normalized, f, ensure_ascii=False, indent=2)
            normalized_ref = f"artifacts/normalized/{run_id}/{normalized_name}"

            judge = llm_judge(accuracy_verdict, claim_rate, slot_rate, output_text)
            if judge["from_llm"]:
                needs_review = judge["triggered"] and (judge["judge_verdict"] != accuracy_verdict or judge["judge_confidence"] < 0.6)
            else:
                needs_review = judge["triggered"] and (judge["judge_verdict"] != accuracy_verdict)
            scored_sample = not needs_review

            assertion_payload = {
                "run_id": run_id,
                "target_id": target,
                "scenario_id": task["scenarioId"],
                "attempt_index": attempt_index,
                "sample_class": sample_class,
                "claim_breakdown": claim_breakdown,
                "slot_breakdown": slot_breakdown,
                "claim_rate": round(claim_rate, 4),
                "slot_rate": round(slot_rate, 4),
                "rule_accuracy_verdict": accuracy_verdict,
                "rule_completeness_verdict": completeness_verdict,
                "judge_verdict": judge["judge_verdict"],
                "judge_confidence": judge["judge_confidence"],
                "judge_reason": judge["judge_reason"],
                "needs_review": needs_review,
            }
            assertion_name = f"{target}-{task['scenarioId']}-a{attempt_index}-{sample_class}.json"
            assertion_abs = assertion_dir / assertion_name
            with open(assertion_abs, "w", encoding="utf-8") as f:
                json.dump(assertion_payload, f, ensure_ascii=False, indent=2)
            assertion_ref = f"artifacts/assertions/{run_id}/{assertion_name}"

            record = {
                "run_id": run_id,
                "target_id": target,
                "scenario_id": task["scenarioId"],
                "attempt_index": attempt_index,
                "sample_class": sample_class,
                "status": "success" if status == "success" else "failure",
                "started_at": started,
                "finished_at": finished,
                "duration_ms": elapsed,
                "call_count": call_count,
                "output_length": output_len,
                "avg_token_per_call": tokens,
                "total_token_per_task": tokens * call_count,
                "token_observability": "none",
                "tokenizer_spec": "cl100k_base",
                "driver_profile": "controlled-agent-v1",
                "truth_baseline": "xcode-16.0-ios-18.0",
                "overfetch_flag": overfetch_flag,
                "error_category": None if status == "success" else "service_unavailable",
                "evidence_refs": [f"artifacts/evidence/{run_id}/{target}-{task['scenarioId']}.txt"],
                "normalized_evidence_ref": normalized_ref,
                "assertion_ref": assertion_ref,
                "accuracy_verdict": accuracy_verdict,
                "completeness_verdict": completeness_verdict,
                "claim_rate": round(claim_rate, 4),
                "slot_rate": round(slot_rate, 4),
                "claim_breakdown": claim_breakdown,
                "slot_breakdown": slot_breakdown,
                "judge_verdict": judge["judge_verdict"],
                "judge_confidence": round(judge["judge_confidence"], 4),
                "judge_reason": judge["judge_reason"],
                "needs_review": needs_review,
                "scored_sample": scored_sample,
                "reviewer_notes": f"claim_rate={claim_rate:.2f};slot_rate={slot_rate:.2f};needs_review={needs_review}",
                "format_extractability": format_extractability,
                "format_density": format_density,
                "format_task_fit": format_task_fit,
                "format_noise": format_noise,
                "format_citability": format_citability,
                "format_notes": f"task_type={task['type']}",
            }
            out.write(json.dumps(record, ensure_ascii=False) + "\n")
PY

log "shared scenario records written to ${OUTPUT_FILE}"
