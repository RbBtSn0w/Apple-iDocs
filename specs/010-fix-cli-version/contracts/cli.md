# CLI Contract: `idocs --version`

## Command
`idocs --version` or `idocs -v`

## Expected Output
```text
1.3.1
```
(Or whatever the string provided in `CommandConfiguration.version` is). It will be printed to stdout.

## Changes to `--help`

```text
USAGE: idocs <subcommand>

OPTIONS:
  -v, --version           Show the version.
  -h, --help              Show help information.
```
