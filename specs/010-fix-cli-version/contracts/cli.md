# CLI Contract: `idocs --version`

## Command
`idocs --version` or `idocs -v`

## Expected Output
```text
1.3.1
```
The value is printed to stdout and MUST match the distribution metadata for the built artifact: `idocs.version` for release bundles or `npm/package.json` for local development builds.

## Changes to `--help`

```text
USAGE: idocs [--version] <subcommand>

OPTIONS:
  -v, --version           Show the version.
  -h, --help              Show help information.
```
