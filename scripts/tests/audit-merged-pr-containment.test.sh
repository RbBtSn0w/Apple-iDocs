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
# A real commit object that exists but is not an ancestor of HEAD. Fabricated
# via commit-tree so the test is deterministic regardless of which historical
# orphans happen to be present locally: `git merge-base --is-ancestor` returns a
# controlled exit 1 (not 128) for a valid-but-unreachable object. The commit is
# a harmless dangling object that future `git gc` reclaims.
empty_tree="$(git -C "${repo_root}" hash-object -w -t tree /dev/null)"
missing_oid="$(git -C "${repo_root}" commit-tree "${empty_tree}" -m 'synthetic unreachable commit for audit test')"

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

# Case 4: an absent object reports a controlled exit 1, never a raw git 128.
# Run inside an isolated repo with no `origin` remote so the script's targeted
# fetch fails instantly without touching the network.
iso_repo="${workdir}/iso-repo"
git init -q "${iso_repo}"
git -C "${iso_repo}" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "base"
iso_base="$(git -C "${iso_repo}" rev-parse HEAD)"
absent_oid="0000000000000000000000000000000000000004"
stub4="${workdir}/gh-absent"
printf '5\tmain\t%s\t2026-04-24T05:08:10Z\thttps://x/5\tabsent object pr\n' "${absent_oid}" \
  | make_stub_gh "${stub4}"
set +e
( cd "${iso_repo}" && env GH_BIN="${stub4}" BASE_REF="${iso_base}" bash "${script}" ) \
  >"${workdir}/out.log" 2>&1
absent_exit=$?
set -e
if [[ "${absent_exit}" -ne 1 ]]; then
  echo "FAIL: absent object controlled exit (expected 1, got ${absent_exit})"
  cat "${workdir}/out.log"
  exit 1
fi
if ! grep -q "object not found in repository" "${workdir}/out.log"; then
  echo "FAIL: absent object did not produce the expected diagnostic"
  cat "${workdir}/out.log"
  exit 1
fi
echo "ok: absent object controlled exit"

echo "All audit-merged-pr-containment tests passed."
