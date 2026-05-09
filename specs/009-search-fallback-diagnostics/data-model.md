# Data Model: search-fallback-diagnostics

## Entities

### `DocumentationError` (Enum)

Represents the failures that can occur during a documentation search or fetch.

**Fields / Cases:**
- `notFound`: Emitted when the remote source successfully responds (200 OK) but returns no matching results, or explicitly returns a 404 Not Found.
- `networkOrPermissionFailure(reason: String)`: Emitted when `URLSession` fails with a transport error or sandbox restriction (e.g., `Operation not permitted`, `notConnectedToInternet`).

### `DiagnosticResult` (Struct)

Represents a structured diagnostic output to be rendered by the CLI formatter.

**Fields:**
- `status`: Enum (`success`, `notFound`, `networkFailure`)
- `message`: String (Actionable message for the user/agent)
- `source`: Enum (`local`, `remoteApple`, `remoteSosumi`)
- `underlyingError`: String? (The specific `POSIXError` or `URLError` description)

## State Transitions

- **Search Starts**: Check local Xcode cache.
  - If found: return local results.
  - If missing/fails: Transition to `Remote Fallback (Apple)`.
- **Remote Fallback (Apple)**: Execute `URLSession` request.
  - If success + results: return results.
  - If success + empty / 404: Transition to `Remote Fallback (Sosumi)`.
  - If `URLError` / `POSIXError`: Emit `DocumentationError.networkOrPermissionFailure` and **HALT** (do not try sosumi if the network is down/blocked, though trying sosumi might also just yield the same error, failing fast is better or accumulating errors). Wait, the spec says "produce actionable diagnostics that tell an agent whether retrying with network access is likely to help." If Apple remote fails due to sandbox, sosumi will also fail. It's better to immediately return the network failure.
- **Remote Fallback (Sosumi)**: Execute `URLSession` request.
  - If success + results: return results.
  - If success + empty / 404: Emit `DocumentationError.notFound`.
  - If `URLError` / `POSIXError`: Emit `DocumentationError.networkOrPermissionFailure`.
