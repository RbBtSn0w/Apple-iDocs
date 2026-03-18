# Quickstart: Working with the Three-Layer Architecture

## Setup
1.  **Generate Project**: `tuist install && tuist generate`
2.  **Verify Targets**:
    *   `iDocsKit`: The Common framework.
    *   `iDocsAdapter`: The Adapter framework.
    *   `iDocs`: The CLI application.

## Developing for the Common Layer (`iDocsKit`)
- All logic for fetching and rendering MUST be in `iDocsKit`.
- **Constraint**: Do NOT import `ArgumentParser` in any `iDocsKit` file.
- **Testing**: Add unit tests in `iDocsKitTests`.

## Adding a New Tool (Application Layer)
1.  **Define Adapter**: If needed, update `DocumentationService` protocol in `iDocsAdapter`.
2.  **Inject Context**: Initialize the `DocumentationService` and inject a `DocumentationConfig`.
3.  **Use async/await**: Call search/fetch methods asynchronously.

## Testing with Mocks
Use `MockDocumentationAdapter` to simulate scenarios in the Application layer:
```swift
CLIEnvironment.serviceFactory = {
    MockDocumentationAdapter(searchResults: [...])
}
let code = await CLIExecutor.runSearch(query: "SwiftUI")
assert(code == 0)
```

## Architecture Gate (SC-005..SC-009)
Run the gate locally before pushing:

```bash
./scripts/arch-gate.sh
```

CI workflow:
- `.github/workflows/dependency-gate.yml` runs the same gate script on push and pull requests.

## CLI Commands (AsyncParsableCommand)

```bash
idocs search "SwiftUI"
idocs fetch "/documentation/swiftui/view"
idocs list --category Frameworks
```

## Build Framework Artifacts

Build distributable XCFrameworks for App integration:

```bash
./scripts/build-xcframework.sh
```

## Silent Run/Test (Recommended)

Use quiet terminal-only commands (no Xcode IDE interaction):

```bash
./scripts/tuist-silent.sh build iDocs
./scripts/tuist-silent.sh run idocs --help
./scripts/tuist-silent.sh test
./scripts/tuist-silent.sh test-all
```

Notes:
- The script runs `xcodebuild` in a low-noise mode (summary on success, tail logs on failure).
- `tuist generate` is only invoked when `iDocs.xcworkspace` is missing.
