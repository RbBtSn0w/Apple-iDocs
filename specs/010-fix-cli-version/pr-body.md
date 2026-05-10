## Summary
Add missing --version support in idocs CLI and decouple it from coreVersion

## Spec Coverage
All requirements from the spec are fully implemented and verified via unit tests and CLI integration checks.

## Verification Evidence
- Test suite: 67 tests executed, all passing
- Unit Tests: `iDocsCLITests.swift` verifies the `CommandConfiguration.version` matches `1.3.1`
- Spec coverage: 100% requirements verified

## Review
Consider running `/speckit.superb.critique` for spec-aligned review.