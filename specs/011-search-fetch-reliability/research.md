# Research: Search and Fetch Reliability for Mixed Apple Documentation Sources

## Decision: Classify source kind from normalized result path/URL

**Rationale**: Apple page family is visible from the path prefix for the issue cases: `/documentation/...`, `/help/...`, `/videos/...`, `/news`, and `/app-store-connect/...`. Classification can be deterministic, testable, and independent of remote payload shape.

**Alternatives considered**:

- Infer from title or result type only. Rejected because sosumi result types are too coarse for Help/news/video separation.
- Delay classification until fetch. Rejected because users need fetchability before choosing a result.

## Decision: Expose fetch capability on every search result

**Rationale**: The core issue is search returning results that later fail as misleading `NOT_FOUND` fetches. A `fetchSupported` contract lets agents avoid unsupported paths and reserve web browsing for deliberate fallback.

**Alternatives considered**:

- Let fetch errors explain support status later. Rejected because this preserves the broken workflow.
- Hide unsupported results. Rejected because users still need to see real Apple pages and understand why `idocs fetch` may not cover them.

## Decision: Keep query normalization as fallback provenance, not as a replacement query

**Rationale**: The original query is user intent and must remain visible. Derived keyword-oriented attempts can improve recall when Apple remote search misses, but every result must still record which query attempt produced it.

**Alternatives considered**:

- Always rewrite broad queries before searching. Rejected because it hides user intent and can reduce precision.
- Skip query normalization. Rejected because issue #8 identified broad Apple/Xcode Cloud queries as a reliability gap.

## Decision: Add ordered fetch source-attempt diagnostics

**Rationale**: Fetch currently logs fallback behavior but returns only final source or final error. The issue requires distinguishing primary decode failures from fallback HTTP failures and showing all attempted sources in order.

**Alternatives considered**:

- Add only final source metadata. Rejected because it does not explain failed primary attempts.
- Put source attempts only in logs. Rejected because agents need machine-readable CLI output.

## Decision: Fetch App Store Connect Help pages through a focused Help adapter

**Rationale**: Help pages are real Apple evidence pages and are important to App Store/TestFlight workflows. A narrow adapter for `developer.apple.com/help/app-store-connect/...` avoids treating these pages as missing documentation while keeping unsupported families explicit.

**Alternatives considered**:

- Treat all Help pages as unsupported. Rejected because it would leave the highest-value issue path unresolved.
- Build a general browser scraper. Rejected as too broad and unnecessary for this feature.

## Decision: Return explicit unsupported-source errors for video/news/unsupported marketing paths

**Rationale**: These paths may be real Apple pages but are not equivalent to missing documentation. Distinct classification avoids misleading `NOT_FOUND` errors and supports deliberate web fallback.

**Alternatives considered**:

- Map unsupported paths to `NOT_FOUND`. Rejected because that is the reported bug.
- Attempt network fetch for every unknown path. Rejected because it adds latency and ambiguous parsing behavior.

## Decision: Preserve existing CLI compatibility by adding optional JSON fields and compact text markers

**Rationale**: Existing callers should continue decoding old fields while newer agents can use source kind, fetchability, query attempts, and fetch diagnostics.

**Alternatives considered**:

- Replace existing payload fields. Rejected as unnecessary API breakage.
- Only support diagnostics in text output. Rejected because agents need structured output.
