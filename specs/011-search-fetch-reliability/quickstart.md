# Quickstart: Search and Fetch Reliability for Mixed Apple Documentation Sources

## Prerequisites

- Generate the project without opening Xcode:

```sh
tuist generate --no-open
```

- Run the default headless test command:

```sh
tuist test iDocs --inspect-mode local --no-upload --no-selective-testing -- -destination 'platform=macOS,name=My Mac'
```

## Scenario 1: Classified Mixed Search Results

```sh
idocs search "Xcode Cloud TestFlight App Store Connect" --json
```

Expected:

- Every result includes `source_kind`.
- Every result includes `fetch_supported`.
- Unsupported videos/news/marketing pages include `fetch_support_reason`.
- Fallback results expose `query_attempt`.

## Scenario 2: App Store Connect Help Fetch

```sh
idocs fetch /help/app-store-connect/manage-builds/upload-builds --json
idocs fetch /help/app-store-connect/test-a-beta-version/testflight-overview --json
```

Expected:

- Fetch succeeds with readable title/body/source URL, or returns explicit unsupported/fetch-failed classification.
- Real Help pages are not reported as `NOT_FOUND`.

## Scenario 3: Decode Failure With Successful Fallback

```sh
idocs fetch /documentation/xcode/environment-variable-reference --json
```

Expected:

- Final `source` identifies the successful source.
- `fetch_diagnostics` includes the failed Apple attempt and the successful fallback attempt.

## Scenario 4: Aggregate Fetch Failure

```sh
idocs fetch /documentation/appstoreconnectapi --json
```

Expected:

- If all sources fail, the error summarizes every attempted source in order.
- Apple decode failure and fallback HTTP failure remain distinct categories.

## Scenario 5: Missing Local Documentation Cache

Run search with a configuration or fixture where the local Xcode documentation cache is unavailable.

Expected:

- Search continues to remote sources.
- Diagnostics include a machine-readable `local_docs_unavailable` or equivalent remote-only signal.

## Verification

Run:

```sh
tuist test iDocs --inspect-mode local --no-upload --no-selective-testing -- -destination 'platform=macOS,name=My Mac'
git diff --check
```
