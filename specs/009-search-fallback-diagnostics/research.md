# Research: search-fallback-diagnostics

## Topic 1: Differentiating Network/Permission Failures from True Zero Results

**Context**: When local Xcode DocumentationCache is not found, `idocs search` falls back to remote APIs (Apple, then sosumi). We need to clearly distinguish when the remote request fails because the app is sandboxed or lacks network access vs when the documentation genuinely does not exist.

**Decision**: 
Capture specific `URLError` codes (such as `notConnectedToInternet`, `networkConnectionLost`) and underlying `POSIXError` or `CocoaError` codes (e.g., "Operation not permitted" which is `EPERM` usually thrown in macOS sandboxes without network entitlement) from `URLSession`. Wrap these in a newly defined or updated `DocumentationError.networkOrPermissionFailure(reason: String)`.
Conversely, a 404 HTTP response or a successful 200 OK with an empty results array should be wrapped in `DocumentationError.notFound`.

**Rationale**: 
Using `URLSession`'s native error throwing allows us to cleanly map transport/permission issues. Distinguishing this at the adapter/service boundary allows the CLI output formatter to present a structured diagnostic error (e.g., "Error: Network lookup failed - Operation not permitted. You may need to grant network access.") rather than a misleading "No results found."

**Alternatives considered**: 
- Trying a ping to a known server before making the request: Rejected because it adds latency and doesn't handle application-specific sandbox permissions correctly.
- Parsing error strings directly: Rejected as brittle; inspecting the error domain and code (`URLError` or `NSURLErrorDomain`) is more robust and aligns with Swift's type safety principle (Constitution VII).
