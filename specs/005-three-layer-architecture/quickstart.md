# Quickstart: Working with the Three-Layer Architecture

## Setup
1.  **Generate Project**: `tuist install && tuist generate`
2.  **Verify Targets**:
    *   `iDocsKit`: The Common/Adapter framework.
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
let mockAdapter = MockDocumentationAdapter(mockResults: [...])
let cli = iDocs(service: mockAdapter)
try await cli.run(["search", "SwiftUI"])
```
