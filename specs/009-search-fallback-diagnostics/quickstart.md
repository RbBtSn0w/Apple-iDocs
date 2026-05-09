# Quickstart: search-fallback-diagnostics

## Overview

This feature enhances `idocs search` so missing local Xcode documentation, remote no-result misses, and remote network or permission failures are distinguishable in CLI output.

## Build And Test

```bash
tuist install
tuist build
tuist test --inspect-mode local --no-selective-testing -- -destination 'platform=macOS,name=My Mac'
```

Tuist owns the project graph through `Project.swift`; `Tuist/Package.swift` is only the SwiftPM third-party dependency entry point.
Root `Package.swift` manifests are reserved for SDK repositories that publish a SwiftPM release contract.

For a deterministic full test-target run:

```bash
tuist test --inspect-mode local --no-selective-testing --test-targets iDocsTests -- -destination 'platform=macOS,name=My Mac'
tuist test --inspect-mode local --no-selective-testing --test-targets iDocsAdapterTests -- -destination 'platform=macOS,name=My Mac'
```

Locate the built binary if you are running directly from a source checkout:

```bash
IDOCS_BIN="$(find .deriveddata Derived "$HOME/Library/Developer/Xcode/DerivedData" -path '*/Build/Products/Debug/idocs' -type f 2>/dev/null | tail -1)"
"$IDOCS_BIN" --help
```

## Manual Validation

### True Not Found

```bash
"$IDOCS_BIN" search --json "SomeFakeAPIThatDoesntExistInApple"
```

Expected result:

- `result_count` is `0`
- `exit_category` is `OK`
- `search_diagnostics` contains `remote_no_results`
- no `remote_permission_denied` or `remote_network_failure` reason is present

### Valid Remote Fallback

```bash
"$IDOCS_BIN" search --json "NavigationSplitView"
"$IDOCS_BIN" search --json "inspectorColumnWidth"
"$IDOCS_BIN" search --json "macOS split views inspector sidebar SwiftUI"
```

Expected result:

- `NavigationSplitView` returns `/documentation/swiftui/navigationsplitview`
- `inspectorColumnWidth` returns `/documentation/swiftui/view/inspectorcolumnwidth(min:ideal:max:)`
- split-view HIG terminology returns official Apple HIG pages

### Network Or Permission Failure

Run with local cache unavailable and outbound network blocked:

```bash
"$IDOCS_BIN" search --json "SwiftUI inspector"
```

Expected result:

- output remains CLI-only JSON
- `search_diagnostics` contains an actionable failure reason such as `remote_permission_denied`, `remote_network_failure`, or `remote_timeout`
- the failure is distinguishable from `remote_no_results`
