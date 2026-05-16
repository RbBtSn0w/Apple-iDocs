# idocs search returns module-level results for composite API queries and misses exact symbols when remote fallback is unavailable

## Summary

`idocs search` often returns only a framework/module-level result such as `/documentation/SwiftUI` for composite queries like `SwiftUI NavigationSplitView`. Exact symbol queries such as `NavigationSplitView` or `NSSplitViewController` do not resolve from the local Xcode index in this environment and then depend on remote Apple/sosumi fallback. When remote fallback is blocked, times out, or unavailable, the command returns no result even though the documentation page exists upstream.

This makes agent use feel like "idocs can only find SwiftUI, but not the actual API."

## Environment

- Date observed: 2026-05-16
- CLI path: `/Users/snow/.nvm/versions/node/v25.8.2/bin/idocs`
- CLI version: `1.5.0`
- Apple-iDocs checkout observed: `main` at `9294730`
- Local Xcode documentation cache observed at: `/Users/snow/Library/Developer/Xcode/DocumentationCache/v302/26.4.1/DeveloperDocumentation.index`
- Local cache shape: `DeveloperDocumentation.index` exists; no `documentation/` directory was found under the checked max-depth sample.

## Reproduction

Run:

```sh
idocs search "SwiftUI NavigationSplitView" --json
```

Observed:

```json
{
  "query": "SwiftUI NavigationSplitView",
  "result_count": 1,
  "results": [
    {
      "id": "/documentation/SwiftUI",
      "query_attempt": "SwiftUI NavigationSplitView",
      "snippet": "Matched module name in local Xcode documentation index.",
      "source": "local",
      "title": "SwiftUI"
    }
  ],
  "search_diagnostics": [
    {
      "name": "cache",
      "reason": "cache_miss",
      "status": "miss"
    },
    {
      "name": "local",
      "result_count": 1,
      "status": "hit"
    }
  ],
  "selected_paths": ["/documentation/SwiftUI"],
  "source": "local"
}
```

Run:

```sh
idocs search "NSWindow toolbarStyle" --json
```

Observed:

```json
{
  "query": "NSWindow toolbarStyle",
  "result_count": 1,
  "results": [
    {
      "id": "/documentation/NSWindow",
      "query_attempt": "NSWindow toolbarStyle",
      "snippet": "Matched module name in local Xcode documentation index.",
      "source": "local",
      "title": "NSWindow"
    }
  ],
  "selected_paths": ["/documentation/NSWindow"],
  "source": "local"
}
```

Run:

```sh
idocs search "NavigationSplitView" --json
```

Observed in sandboxed run:

```json
{
  "query": "NavigationSplitView",
  "result_count": 0,
  "results": [],
  "search_diagnostics": [
    {
      "name": "local",
      "reason": "local_no_results",
      "status": "miss",
      "hint": "Local Xcode documentation did not return a match; remote Apple and sosumi fallbacks will be attempted."
    },
    {
      "name": "apple",
      "reason": "remote_permission_denied",
      "status": "error",
      "hint": "Retry with network permission enabled; this does not prove the documentation page is missing."
    },
    {
      "name": "sosumi",
      "reason": "remote_permission_denied",
      "status": "error",
      "hint": "Retry with network permission enabled; this does not prove the documentation page is missing."
    }
  ],
  "selected_paths": []
}
```

Observed with network permission outside the sandbox:

```json
{
  "query": "NavigationSplitView",
  "result_count": 0,
  "results": [],
  "search_diagnostics": [
    {
      "name": "local",
      "reason": "local_no_results",
      "status": "miss"
    },
    {
      "name": "apple",
      "reason": "remote_timeout",
      "status": "error",
      "hint": "Retry with a longer timeout or working network before treating this as a documentation miss."
    },
    {
      "name": "sosumi",
      "reason": "remote_timeout",
      "status": "error",
      "hint": "Retry with a longer timeout or working network before treating this as a documentation miss."
    }
  ],
  "selected_paths": []
}
```

Run:

```sh
idocs search "NSSplitViewController" --json
```

Observed:

```json
{
  "query": "NSSplitViewController",
  "result_count": 0,
  "results": [],
  "search_diagnostics": [
    {
      "name": "local",
      "reason": "local_no_results",
      "status": "miss"
    },
    {
      "name": "apple",
      "reason": "remote_permission_denied",
      "status": "error"
    },
    {
      "name": "sosumi",
      "reason": "remote_permission_denied",
      "status": "error"
    }
  ],
  "selected_paths": []
}
```

## Expected Behavior

For API-symbol oriented queries:

- `idocs search "SwiftUI NavigationSplitView"` should prefer or at least include the symbol-level result before returning only `/documentation/SwiftUI`.
- `idocs search "NSWindow toolbarStyle"` should not stop at `/documentation/NSWindow` if a more specific member page is available or likely.
- `idocs search "NavigationSplitView"` should be able to recover a likely SwiftUI path from local index data or a deterministic symbol-path heuristic before relying entirely on remote search.
- If only module-level results are available, output diagnostics should say that a module hint short-circuited the broader local/remote search and that the returned result is not a symbol-level match.

## Actual Behavior

Composite queries containing a likely module token return as soon as the module hint resolves locally:

- `SwiftUI NavigationSplitView` returns `/documentation/SwiftUI`.
- `NSWindow toolbarStyle` returns `/documentation/NSWindow`.
- The later local provider search, local `DeveloperDocumentation.index` path scan, Apple remote search, and sosumi fallback do not run for these queries.

Exact symbol queries without a module hint miss locally and require remote search. When remote search fails due permission or timeout, the command returns zero results.

## Root Cause Analysis

There are two separate failure modes that combine into the user-visible issue.

### 1. Composite query short-circuits on module hint

In `Sources/iDocsKit/DataSources/XcodeLocalDocs.swift`, `search(query:)` extracts a module hint from composite queries. When that hint finds a local module/index result, the function returns immediately:

```swift
if let moduleHint = extractModuleHint(from: trimmed) {
    let hinted = searchDocumentationRoots(query: moduleHint, sdks: sdks, limit: 20)
    if !hinted.isEmpty {
        logger.info("Recovered \(hinted.count) module-level matches using hint '\(moduleHint)' for query: \(trimmed)")
        return hinted
    }

    let hintedIndexResults = searchIndexStores(query: moduleHint, sdks: sdks)
    if !hintedIndexResults.isEmpty {
        logger.info("Recovered \(hintedIndexResults.count) module-level matches using hint '\(moduleHint)' for query: \(trimmed)")
        return hintedIndexResults
    }
}
```

That behavior is intentionally covered by `Tests/iDocsTests/XcodeLocalDocsMockTests.swift`:

```swift
@Test("Composite queries recover module hint before provider search")
func testCompositeQueryUsesModuleHintFastPath() async throws {
    ...
    let results = try await docs.search(query: "SwiftUI View")

    #expect(results.count == 1)
    #expect(results.first?.title == "SwiftUI")
    #expect(results.first?.path == "/documentation/SwiftUI")
    #expect(results.first?.source == .local)
    #expect(mockSearch.searchCallCount == 0)
}
```

This test encodes module recovery as the final result instead of a fallback candidate. That is the direct reason composite queries stop at `SwiftUI` / `NSWindow`.

### 2. Exact symbol queries do not resolve from local index

For `NavigationSplitView` and `NSSplitViewController`, `XcodeLocalDocs.search` returns `local_no_results`. The tool then depends on remote Apple and sosumi fallbacks. In this environment those fallbacks either fail with `remote_permission_denied` or time out after 5 seconds.

This means exact symbol lookup is fragile unless the symbol path is already recoverable from the local index scan.

## Why this feels like "only SwiftUI works"

The working cases are not actually successful symbol searches. They are early module-level matches:

- `SwiftUI NavigationSplitView` -> `SwiftUI`
- `NSWindow toolbarStyle` -> `NSWindow`

The failing cases are the actual symbol-level searches:

- `NavigationSplitView` -> local miss -> remote error
- `NSSplitViewController` -> local miss -> remote error

So the search pipeline currently optimizes for "find a framework/module anchor quickly" but does not continue searching for the requested symbol once that anchor is found.

## Suggested Fix Direction

Do not remove module-hint recovery entirely; it is useful as a fallback. Instead, change its role from terminal result to candidate/diagnostic unless the original query is itself a module query.

Possible approach:

1. Preserve exact module query behavior:
   - `idocs search "SwiftUI"` may return `/documentation/SwiftUI` immediately.

2. For composite queries:
   - Run symbol/path search for the full query first.
   - Keep module hint results as lower-priority fallback candidates.
   - If module hint is returned, mark it as `match_scope: "module"` or similar.
   - Avoid reporting module result as if it satisfied a symbol query.

3. Improve local exact-symbol recovery:
   - Prefer extracted `/documentation/...` paths from `DeveloperDocumentation.index` when any path component matches the requested symbol.
   - Consider framework-qualified path generation for common DocC conventions, for example:
     - `SwiftUI NavigationSplitView` -> `/documentation/swiftui/navigationsplitview`
     - `AppKit NSSplitViewController` -> `/documentation/appkit/nssplitviewcontroller`
   - Validate generated paths through `fetch` or cache/index presence before returning as supported.

4. Improve diagnostics:
   - Include a stage field such as `match_scope: module|symbol|member|path`.
   - Include `short_circuited: true` when local module hint prevented broader search.
   - Include an actionable hint: "Only a module-level local result was found; retry exact symbol query or enable remote search."

5. Consider remote timeout configuration:
   - The current 5-second timeout can turn slow upstream responses into search misses.
   - Expose timeout via CLI/env or include retry guidance in text output.

## Acceptance Criteria

- `idocs search "SwiftUI NavigationSplitView" --json` does not return only `/documentation/SwiftUI` when a symbol-level result can be recovered.
- `idocs search "NSWindow toolbarStyle" --json` clearly distinguishes `/documentation/NSWindow` as a module/type-level fallback, not the member-level result.
- `idocs search "NavigationSplitView" --json` either returns a symbol-level candidate or gives diagnostics that local symbol lookup failed and remote lookup was required.
- Existing fast module lookup remains intact for exact module queries such as `SwiftUI`.
- Tests no longer encode "composite query returns module and skips provider search" as the desired terminal behavior; they should assert the new fallback/candidate semantics instead.

## Impact

This affects the core agent workflow for Apple-fact lookup. Agents are likely to ask framework-qualified questions such as `SwiftUI NavigationSplitView`, `NSWindow toolbarStyle`, or `AppKit NSSplitViewController`. Returning only the framework/type page makes the result look successful while still failing to provide the actual API evidence needed for implementation or explanation.
