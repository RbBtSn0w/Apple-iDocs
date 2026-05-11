## Summary
Add missing --version support in idocs CLI and decouple it from coreVersion

## Spec Coverage
All requirements from the spec are fully implemented and verified via unit tests and CLI integration checks.

## Verification Evidence
- Test suite: `./scripts/tuist-silent.sh test`
- Unit Tests: `CLICommandTests.swift` verifies `-v` / `--version` parsing plus sidecar and package-manifest version resolution
- E2E: `IDOCS_NPM_STRICT_INSTALL=1 ./scripts/e2e-cli.sh offline` verifies `idocs --version` matches `npm/package.json`
- Release config: `bash ./scripts/test-release-config.sh` verifies semantic-release packaging order and the Node engine floor required by release plugins
- Spec coverage: 100% requirements verified

## Review
Consider running `/speckit.superb.critique` for spec-aligned review.
