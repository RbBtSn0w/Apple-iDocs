# Data Model: Tuist Manifests

## Manifests

### 1. Tuist/Config.swift
- **Purpose**: Defines global Tuist settings for the project.
- **Attributes**:
  - `swiftVersion`: 6.0
  - `generationOptions`: `.options()`

### 2. Tuist/Package.swift
- **Purpose**: Defines SPM dependencies for the project.
- **Attributes**:
  - `name`: "iDocs"
  - `platforms`: `.macOS(.v13)`
  - `dependencies`:
    - `swift-sdk`: `0.11.0`
    - `swift-service-lifecycle`: `2.3.0`
    - `swift-log`: `1.5.0`

### 3. Project.swift
- **Purpose**: Defines the Xcode project structure.
- **Attributes**:
  - `name`: "iDocs"
  - `targets`:
    - `iDocs` (Executable):
      - `sources`: `Sources/iDocs/**`
      - `dependencies`: `.external(name: "MCP")`, `.external(name: "ServiceLifecycle")`, `.external(name: "Logging")`
    - `iDocsTests` (UnitTests):
      - `sources`: `Tests/iDocsTests/**`
      - `dependencies`: `.target(name: "iDocs")`

## State Transitions

### Lifecycle of Project Generation
1. **Uninitialized**: Only manifest files exist.
2. **Resolved**: `tuist install` fetches SPM dependencies into `Tuist/.build`.
3. **Generated**: `tuist generate` creates `iDocs.xcworkspace` and `iDocs.xcodeproj`.
4. **Built**: `tuist build` compiles the code into a binary.
5. **Tested**: `tuist test` executes unit tests and reports results.
