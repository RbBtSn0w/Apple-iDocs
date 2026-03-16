# Contract: CLI Interface (iDocs)

## Overview
The CLI application layer (`iDocs`) MUST map user commands to calls on the `DocumentationService` adapter.

## Commands

### 1. `search`
- **Command**: `iDocs search <query>`
- **Arguments**: 
    - `<query>`: The search term (Required).
- **Options**:
    - `--locale`: Override the default locale.
    - `--verbose`: Enable detailed logging.
- **Contract Mapping**: 
    - Calls `adapter.search(query: query, config: config)`.
    - Outputs results as a formatted table in the terminal.

### 2. `fetch`
- **Command**: `iDocs fetch <id>`
- **Arguments**:
    - `<id>`: The documentation identifier (Required).
- **Options**:
    - `--format [markdown|text]`: Select the output format (Default: markdown).
- **Contract Mapping**:
    - Calls `adapter.fetch(id: id, config: config)`.
    - Outputs the `body` of the document to `stdout`.

### 3. `list`
- **Command**: `iDocs list`
- **Options**:
    - `--category <name>`: Filter by category.
- **Contract Mapping**:
    - Calls `adapter.listTechnologies(config: config)`.
    - Outputs list of technologies.

## Error Handling
The CLI must catch `DocumentationError` and output a user-friendly message to `stderr`:
- `.notFound`: "Error: Documentation for '<id>' could not be found."
- `.networkError`: "Error: Network connection failed. Using local cache only."
- `.internalError`: "Error: A system error occurred: <message>"
