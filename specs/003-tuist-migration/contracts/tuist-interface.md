# Contract: Tuist CLI Interface

## Overview
The primary interface for project management after migration will be the Tuist CLI. This contract defines the expected commands and their outcomes.

## Commands

### 1. Dependency Resolution
- **Command**: `tuist install`
- **Pre-condition**: `Tuist/Package.swift` exists and is valid.
- **Outcome**: Downloads and resolves SPM packages into the `Tuist/` directory.

### 2. Project Generation
- **Command**: `tuist generate`
- **Pre-condition**: `tuist install` has been run successfully.
- **Outcome**: 
  - Creates `iDocs.xcworkspace` in the root directory.
  - Creates `iDocs.xcodeproj` in the root directory.
  - Links all `.external` and `.target` dependencies.

### 3. Build Process
- **Command**: `tuist build [target]`
- **Pre-condition**: Project has been generated.
- **Outcome**: 
  - Successfully compiles the specified target (default: `iDocs`).
  - Produces an executable binary in the build directory.

### 4. Test Execution
- **Command**: `tuist test [target]`
- **Pre-condition**: Project has been generated.
- **Outcome**: 
  - Compiles and runs unit tests for the specified target (default: `iDocsTests`).
  - Reports pass/fail status for each test case.

## Schema for Target Definitions
Targets defined in `Project.swift` MUST follow this structure to ensure compatibility:

```swift
.target(
    name: String,
    destinations: Destinations,
    product: Product,
    bundleId: String,
    deploymentTargets: DeploymentTargets,
    sources: SourceFilesList,
    dependencies: [TargetDependency]
)
```
