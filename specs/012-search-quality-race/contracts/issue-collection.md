# Contract: Search Quality Issue Collection

## Scope

Issue collection is only for actionable iDocs golden-truth failures.

The collector must ignore:

- Competitor failures.
- iDocs network errors.
- Infrastructure failures.
- Not-applicable results.
- No-failure runs.

## Fingerprint

The fingerprint input is:

1. Sorted actionable failing case IDs.
2. Expected outcomes for those case IDs.
3. iDocs classifications for those case IDs.

The hash algorithm may be implementation-defined, but the fingerprint must be stable across case execution order.

## Existing Issue Lookup

The collector must search open issues for the fingerprint. If a matching open issue exists, it must append a comment rather than create a duplicate issue.

## New Issue Body

New issues must include:

- CI run URL.
- Seed and sample size.
- Failing cases table.
- iDocs diagnostics.
- Competitor versions.
- Artifact location.
- Local reproduction command.
- Failure fingerprint.

## Existing Issue Comment

Comments on matching issues must include:

- CI run URL.
- Latest report/artifact links.
- Failure fingerprint.

## Label Behavior

Preferred labels are:

- `search-quality`
- `automated`
- `benchmark`

Label application is best effort. Missing labels must not block issue creation.

## Dry-Run Behavior

Dry-run or print-body mode must produce the issue body/comment content and collector decision without mutating GitHub.
