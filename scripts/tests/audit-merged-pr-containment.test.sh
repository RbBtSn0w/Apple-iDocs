#!/usr/bin/env bash
# Focused tests for scripts/audit-merged-pr-containment.sh.
#
# Strategy: stub `gh` so it emits a fixed TSV of merged PRs, and point BASE_REF
# at real commits in this repo (HEAD is contained; a known-orphan SHA is not).
# This exercises the containment check, the non-zero exit on a missing commit,
# and the EXCLUDE_PRS exception path without any network access.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="${repo_root}/scripts/audit-merged-pr-containment.sh"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

# A SHA that is reachable from HEAD (always contained).
contained_oid="$(git -C "${repo_root}" rev-parse HEAD)"
# A SHA that is not an ancestor of HEAD: the orphaned PR #4 merge commit.
# Fall back to a synthetic all-zero-ish SHA if that object is absent locally.
missing_oid="1004b89ed80da3235b812dc0f2169baf2a96d588"
if ! git -C "${repo_root}" cat-file -e "${missing_oid}^{commit}" 2>/dev/null; then
  missing_oid="0000000000000000000000000000000000000004"
fi

make_stub_gh() {
  # $1: path to write the stub; remaining lines come from stdin as TSV rows.
  local stub_path="$1"
  local rows
  rows="$(cat)"
  cat > "${stub_path}" <<STUB
#!/usr/bin/env bash
# Ignore all args; the real script only consumes the --jq TSV output.
cat <<'ROWS'
${rows}
ROWS
STUB
  chmod +x "${stub_path}"
}

run_case() {
  local name="$1"; shift
  local expected_exit="$1"; shift
  local stub="$1"; shift
  set +e
  env GH_BIN="${stub}" BASE_REF="${contained_oid}" "$@" bash "${script}" >"${workdir}/out.log" 2>&1
  local actual_exit=$?
  set -e
  if [[ "${actual_exit}" -ne "${expected_exit}" ]]; then
    echo "FAIL: ${name} (expected exit ${expected_exit}, got ${actual_exit})"
    cat "${workdir}/out.log"
    exit 1
  fi
  echo "ok: ${name}"
}

# Case 1: all merged PR commits contained -> exit 0.
stub1="${workdir}/gh-all-contained"
printf '101\tmain\t%s\t2026-06-01T00:00:00Z\thttps://x/101\tcontained pr\n' "${contained_oid}" \
  | make_stub_gh "${stub1}"
run_case "all contained passes" 0 "${stub1}"

# Case 2: a missing commit -> non-zero exit (fails the build, not just logs).
stub2="${workdir}/gh-missing"
{
  printf '101\tmain\t%s\t2026-06-01T00:00:00Z\thttps://x/101\tcontained pr\n' "${contained_oid}"
  printf '4\tmain\t%s\t2026-04-24T05:08:10Z\thttps://x/4\torphaned pr\n' "${missing_oid}"
} | make_stub_gh "${stub2}"
run_case "missing commit fails" 1 "${stub2}"

# Case 3: same missing commit, excluded via EXCLUDE_PRS -> exit 0.
run_case "excluded pr passes" 0 "${stub2}" EXCLUDE_PRS=4

echo "All audit-merged-pr-containment tests passed."
