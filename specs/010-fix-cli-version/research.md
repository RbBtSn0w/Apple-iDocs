# Research: CLI Version Support

## Decision: Expose Package Version via Swift Compiler Flag (or constant string)

**Decision**: 
The `idocs` CLI will expose a `--version` / `-v` flag using `swift-argument-parser`'s built-in `.version` configuration, or by adding a global version flag to the main configuration. 
Since `swift package` is not used (Tuist is the project generator), and the version must match the NPM package version (e.g. `1.3.1`), we will hardcode the version string in the `iDocsCLI.configuration` as `version: "1.3.1"`. 

The release script (`scripts/release-package.sh`) or a pre-build step might ideally inject this, but for now, we will manually keep it in sync with `npm/package.json` (1.3.1), as doing dynamic injection in Tuist without breaking local `tuist generate` is complex. 
We will decouple this from `coreVersion` in `iDocsKit/Utils/Version.swift`, which remains for ABI/adapter compatibility.

**Rationale**: 
`ArgumentParser` provides a native `version` property in `CommandConfiguration`.
```swift
    public static let configuration = CommandConfiguration(
        commandName: "idocs",
        abstract: "iDocs CLI",
        version: "1.3.1", // <--- Native support
        subcommands: [SearchCommand.self, FetchCommand.self, ListCommand.self]
    )
```
This automatically handles `--version` and `-v` globally, and injects it into `--help`. This satisfies all requirements with minimal code change.

**Alternatives considered**:
1. **NPM wrapper injection**: Blocked because it doesn't affect `idocs --help` output produced by the Swift binary.
2. **Tuist Build Phase / Info.plist injection**: Overly complex for a simple CLI tool, and we don't use `Bundle.main.infoDictionary` in typical SPM/Tuist CLI targets easily.

## Decision: Hardcoding Version in `CommandConfiguration`
**Decision**: Update `iDocsCLI.configuration` in `Sources/iDocs/Commands/iDocsCLI.swift` to include `version: "1.3.1"`.
**Rationale**: `package.json` currently has version `1.3.0` but the prompt mentions `1.3.1`. I will use `1.3.1` (or whatever the target version is, let's bump `npm/package.json` to 1.3.1 to match).

## Constitution Check
- **II. Stateless CLI/Adapter Design**: Does not add state.
- **V. Simplicity**: Uses the built-in capability of `ArgumentParser` (YAGNI).
- **VI. Native Swift First**: Uses `swift-argument-parser` natively.

All decisions align with the constitution.