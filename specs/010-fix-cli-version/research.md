# Research: CLI Version Support

## Decision: Resolve CLI Version from Release Metadata

**Decision**: 
The `idocs` CLI will expose a `--version` / `-v` flag using the main ArgumentParser command. The reported value is resolved from release metadata rather than the internal `coreVersion`:

1. `IDOCS_CLI_VERSION` override for controlled test or diagnostic environments.
2. `idocs.version` sidecar next to the executable for published release bundles and npm-installed binaries.
3. The nearest repository `npm/package.json` for local development builds.
4. `0.0.0-dev` only as a final development fallback.

`scripts/release-package.sh` writes `idocs.version` into the release bundle, and semantic-release runs that packaging step during `prepare` with `${nextRelease.version}` so the packaged binary reports the version being published.

**Rationale**: 
Hardcoding the version in Swift source would drift after the next semantic-release bump. A sidecar keeps the binary release artifact self-describing while keeping `coreVersion` reserved for Adapter/Core ABI compatibility.
```swift
if version {
    print(CLIVersion.current())
}
```

**Alternatives considered**:
1. **NPM wrapper injection**: Blocked because it only affects npm execution and not direct release-bundle execution.
2. **Hardcoded Swift constant**: Rejected because it drifts from semantic-release output.
3. **Info.plist injection**: Avoided because command-line tool bundle metadata is not already part of this Tuist target's runtime contract.

## Constitution Check
- **II. Stateless CLI/Adapter Design**: Does not add state.
- **V. Simplicity**: Uses a small sidecar and manifest fallback instead of introducing a build-system plugin.
- **VI. Native Swift First**: Uses `swift-argument-parser` natively.

All decisions align with the constitution.
