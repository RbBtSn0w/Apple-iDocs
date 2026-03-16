# Research: Three-Layer Architecture Refactoring

## 1. Cross-process File Locking in Swift
- **Decision**: Do not require cross-process locking by default. CLI and App do not share a cache directory due to App sandbox isolation. If a shared cache is intentionally introduced later (e.g., App Group directory), prefer `Darwin.flock` as an opt-in strategy.
- **Rationale**: Avoids complexity and performance overhead in the default architecture while still providing a clear path for safe sharing if future requirements change.
- **Implementation Note**:
  ```swift
  import Darwin
  let fd = open(lockFilePath, O_RDWR | O_CREAT, 0o666)
  flock(fd, LOCK_EX) // Exclusive lock
  // ... perform disk operations ...
  flock(fd, LOCK_UN) // Unlock
  close(fd)
  ```
- **Alternatives Considered**: 
    - `NSFileCoordinator`: More "Apple-native" but slower and sometimes buggy in CLI environments without a shared coordinator daemon.
    - `Distributed Actors`: Too complex for simple file access.

## 2. DocumentationService Protocol Design
- **Decision**: Define a protocol-based interface in the Adapter layer using Swift Concurrency exclusively.
- **Rationale**: Ensures the Application layer remains agnostic of the underlying fetchers while leveraging modern Swift 6 features.
- **Draft Interface**:
  ```swift
  public protocol DocumentationService: Sendable {
      func search(query: String, config: DocumentationConfig) async throws -> [SearchResult]
      func fetch(id: String, config: DocumentationConfig) async throws -> DocumentationContent
      func listTechnologies(config: DocumentationConfig) async throws -> [Technology]
  }
  ```

## 3. Tuist Modular Structure for Cross-Platform
- **Decision**: The Common layer supports `.framework` / `.xcframework` delivery for App targets. The CLI may link the Common layer statically or dynamically depending on distribution needs.
- **Rationale**: Apps typically need frameworks/xcframeworks, while CLI distribution often benefits from static linking. The architecture should not hard-code a single packaging mode.
- **Alternatives Considered**:
    - `staticLibrary`: Smaller binary for CLI, but harder to share with App targets in some configurations (though technically possible via XCFrameworks).

## 4. Async CLI Implementation
- **Decision**: Migrate all `ParsableCommand` implementations to `AsyncParsableCommand`.
- **Rationale**: Required for the CLI to use `await` when calling the Adapter layer.
- **Reference**: `ArgumentParser` v1.1.0+ supports `AsyncParsableCommand` with `@main` entry point.

## 5. Error Mapping and Standardization
- **Decision**: The Adapter layer will define a `DocumentationError` enum that conforms to `LocalizedError`.
- **Rationale**: Provides a consistent error surface for both CLI (text output) and App (UI alerts).
- **Draft Error Types**:
  ```swift
  public enum DocumentationError: Error {
      case notFound(String)
      case networkError(Error)
      case parsingError(String)
      case unauthorized
      case internalError(String)
  }
  ```
