## Summary
Add missing --version support in idocs CLI and decouple it from coreVersion

## Spec Coverage
All requirements from the spec are fully implemented and verified via unit tests and CLI integration checks.

## Verification Evidence
- Test suite: Swift tests plus offline CLI E2E
- Unit Tests: `CLICommandTests.swift` verifies sidecar and package-manifest version resolution
- E2E: `scripts/e2e-cli.sh offline` verifies `idocs --version` matches `npm/package.json`
- Spec coverage: 100% requirements verified

## Review
Consider running `/speckit.superb.critique` for spec-aligned review.
