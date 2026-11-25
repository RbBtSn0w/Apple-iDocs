#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

failures=0

search() {
  local pattern="$1"
  shift
  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" "$@"
  else
    grep -R -n -E "$pattern" "$@"
  fi
}

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

# iDocsKit must not depend on Application/Adapter targets or MCP runtime dependencies.
kit_block="$(target_block "iDocsKit")"
if grep -Eq '\.target\(name: "iDocs"\)|\.target\(name: "iDocsAdapter"\)|\.external\(name: "MCP"\)|\.external\(name: "ServiceLifecycle"\)' <<< "$kit_block"; then
  fail "Target Dependency Gate: iDocsKit contains forbidden dependencies"
else
  pass "Target Dependency Gate"
fi

# CLI and App must route documentation commands through DocumentationService.
if search '(ResolveDocsTool|SearchDocsTool|FetchDocTool|BrowseTechnologiesTool)[[:space:]]*\(' Sources/iDocsApp Sources/iDocsCLI >/dev/null 2>&1; then
  fail "Adapter Access Gate: CLI targets directly instantiate iDocsKit tools"
else
  pass "Adapter Access Gate"
fi

# Adapter APIs are async-only (no completion handlers).
if search 'completion\s*:' Sources/iDocsAdapter >/dev/null 2>&1; then
  fail "Concurrency Gate: completion handlers detected in Adapter"
elif search 'func\s+(search|fetch|listTechnologies)\(' Sources/iDocsAdapter/Protocols/DocumentationService.swift | grep -vq 'async throws'; then
  fail "Concurrency Gate: service methods are not async throws"
else
  pass "Concurrency Gate"
fi

# App readiness via injected cache path and no hardcoded global writes in adapter path.
if ! search 'cachePath' Sources/iDocsAdapter/Models/DocumentationConfig.swift >/dev/null 2>&1; then
  fail "App Readiness Gate: DocumentationConfig.cachePath missing"
elif ! search 'DiskCache\(' Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift >/dev/null 2>&1; then
  fail "App Readiness Gate: Adapter does not inject cache directory into DiskCache"
elif ! search 'enableFileLocking:\s*config\.enableFileLocking' Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift >/dev/null 2>&1; then
  fail "App Readiness Gate: Adapter does not forward file-locking config"
else
  pass "App Readiness Gate"
fi

# Version gate enforcement in adapter startup.
if ! search 'validateVersionCompatibility' Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift >/dev/null 2>&1; then
  fail "Version Gate: compatibility validator missing"
elif ! search 'validateVersionCompatibility\(adapterVersion: adapterVersion, core: coreVersion\)' Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift >/dev/null 2>&1; then
  fail "Version Gate: init does not enforce version check"
else
  pass "Version Gate"
fi

# Public Adapter and Core interfaces should avoid platform UI types.
if search 'NSView|UIView|NSColor|UIColor|import AppKit|import UIKit' Sources/iDocsAdapter Sources/iDocsKit >/dev/null 2>&1; then
  fail "Cross-platform Interface Audit: platform-specific UI types detected"
else
  pass "Cross-platform Interface Audit"
fi

# Capability guard: source observability for search/fetch.
if ! search 'public let source: RetrievalSource\?' Sources/iDocsAdapter/Models/CoreEntities.swift >/dev/null 2>&1; then
  fail "Capability Gate: adapter search result source metadata missing"
elif ! search '"source"\s*:\s*output\.source\.rawValue' Sources/iDocsAdapter/Adapters/DefaultDocumentationAdapter.swift >/dev/null 2>&1; then
  fail "Capability Gate: fetch source metadata mapping missing"
else
  pass "Capability Gate: source observability"
fi

# Capability guard: dual remote fallback primitive exists.
if [[ ! -f "Sources/iDocsKit/DataSources/SosumiAPI.swift" ]]; then
  fail "Capability Gate: sosumi datasource missing"
else
  pass "Capability Gate: sosumi datasource present"
fi

if [[ "$failures" -gt 0 ]]; then
  printf '\nArchitecture gate failed with %s issue(s).\n' "$failures"
  exit 1
fi

printf '\nArchitecture gate passed.\n'
