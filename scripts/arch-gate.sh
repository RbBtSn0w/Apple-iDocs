#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

failures=0

pass() {
  echo "[PASS] $1"
}

fail() {
  echo "[FAIL] $1"
  failures=$((failures + 1))
}

target_block() {
  local target_name="$1"
  awk -v name="$target_name" '
    $0 ~ "name: \""name"\"" {in_target=1}
    in_target {print}
    in_target && /^        \),$/ {exit}
  ' Project.swift
}

# SC-005: iDocsKit must not depend on Application/Adapter targets or MCP runtime dependencies.
kit_block="$(target_block "iDocsKit")"
if grep -Eq '\.target\(name: "iDocs"\)|\.target\(name: "iDocsAdapter"\)|\.external\(name: "MCP"\)|\.external\(name: "ServiceLifecycle"\)' <<< "$kit_block"; then
  fail "SC-005 Target Dependency Gate: iDocsKit contains forbidden dependencies"
else
  pass "SC-005 Target Dependency Gate"
fi

# SC-006: App layer should not instantiate Common tools directly for search/fetch/list pathways.
if rg -n 'SearchDocsTool\(|FetchDocTool\(|BrowseTechnologiesTool\(' Sources/iDocs >/dev/null 2>&1; then
  fail "SC-006 Access Gate: Sources/iDocs directly instantiates Common tool types"
else
  pass "SC-006 Access Gate"
fi

# SC-007: Adapter APIs are async-only (no completion handlers).
if rg -n 'completion\s*:' Sources/iDocsAdapter >/dev/null 2>&1; then
  fail "SC-007 Concurrency Gate: completion handlers detected in Adapter"
elif rg -n 'func\s+(search|fetch|listTechnologies)\(' Sources/iDocsAdapter/Protocols/DocumentationService.swift | grep -vq 'async throws'; then
  fail "SC-007 Concurrency Gate: service methods are not async throws"
else
  pass "SC-007 Concurrency Gate"
fi

# SC-008: App readiness via injected cache path and no hardcoded global writes in adapter path.
if ! rg -n 'cachePath' Sources/iDocsAdapter/Models/DocumentationConfig.swift >/dev/null 2>&1; then
  fail "SC-008 App Readiness Gate: DocumentationConfig.cachePath missing"
elif ! rg -n 'DiskCache\(' Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift >/dev/null 2>&1; then
  fail "SC-008 App Readiness Gate: Adapter does not inject cache directory into DiskCache"
elif ! rg -n 'enableFileLocking:\s*config\.enableFileLocking' Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift >/dev/null 2>&1; then
  fail "SC-008 App Readiness Gate: Adapter does not forward file-locking config"
else
  pass "SC-008 App Readiness Gate"
fi

# SC-009: Version gate enforcement in adapter startup.
if ! rg -n 'validateVersionCompatibility' Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift >/dev/null 2>&1; then
  fail "SC-009 Version Gate: compatibility validator missing"
elif ! rg -n 'validateVersionCompatibility\(adapterVersion: adapterVersion, core: coreVersion\)' Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift >/dev/null 2>&1; then
  fail "SC-009 Version Gate: init does not enforce version check"
else
  pass "SC-009 Version Gate"
fi

# T017 support: public adapter/common interfaces should avoid platform UI types.
if rg -n 'NSView|UIView|NSColor|UIColor|import AppKit|import UIKit' Sources/iDocsAdapter Sources/iDocsKit >/dev/null 2>&1; then
  fail "T017 Cross-platform Interface Audit: platform-specific UI types detected"
else
  pass "T017 Cross-platform Interface Audit"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "\nArchitecture gate failed with $failures issue(s)."
  exit 1
fi

echo "\nArchitecture gate passed."
