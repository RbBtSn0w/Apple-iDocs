---
name: using-idocs-cli
description: Use when you need to research Apple developer frameworks, API specifications, or SwiftUI documentation directly from the terminal without breaking flow.
---

# Using iDocs CLI

## Overview
iDocs is a high-performance Swift CLI for querying Apple's documentation and rendering Markdown output. It uses layered memory and disk caching (`cache -> local(Xcode) -> apple -> sosumi`) to deliver accurate documentation directly into the terminal context.

## When to Use

- When writing Apple platform code and APIs are unknown or potentially hallucinated.
- When needing to confirm the latest Swift 6 concurrency or SwiftUI property wrapper signatures.
- When you want exact API references without the noise of web search results.

**When NOT to use:**
- For non-Apple ecosystems or languages (Node.js, Rust, Python, etc.).

## Quick Reference

| Action | Command | What It Does |
| ------ | ------- | ------------ |
| Search | `idocs search "<query>"` | Returns matching paths for Apple documentation. |
| Fetch  | `idocs fetch "<path>"` | Outputs high-quality Markdown for a specific document path. |
| List   | `idocs list` | Shows a list of available technology catalogs. |
| Source Run | `./scripts/tuist-silent.sh run idocs -- <cmd>` | Used when running from inside the `Apple-iDocs` repository source tree. |

## Core Pattern: The Two-Step Workflow

Never try to guess the documentation path. Always observe this two-step lifecycle:

```bash
# 1. Search for the concept to find the exact documentation path
idocs search "ViewModifier"
# Output yields paths like: /documentation/swiftui/viewmodifier

# 2. Fetch the Markdown content using the exact path
idocs fetch "/documentation/swiftui/viewmodifier"
```

## Path & Environment Troubleshooting (Command Not Found)

Because `idocs` is installed via `npm` (`npm install -g @rbbtsn0w/idocs`), its executable resides in the exact same global `bin` directory as the active `node` environment. 

If an Agent encounters a `command not found: idocs` error, **do not assume the tool is missing or attempt to build it**. Instead, locate the Node bin path:
1. Check where Node is located: `which node`
2. The `idocs` binary will be in the same directory.
3. Invoke it via absolute path:
   ```bash
   NODE_BIN_DIR=$(dirname $(which node))
   $NODE_BIN_DIR/idocs search "ViewModifier"
   ```
   Or simply rely on `npx`:
   ```bash
   npx @rbbtsn0w/idocs search "ViewModifier"
   ```

## Common Mistakes

| Mistake | Correction |
|---------|-------------|
| Guessing `/documentation/` paths | Paths are strict. Always use `idocs search` first to secure the exact path. |
| Falling back to generic web search | `idocs` strips HTML and formatting noise, leaving only dense, token-efficient Markdown ideal for LLMs and developers. |
| Forgetting offline availability | `idocs` falls back to Xcode doc archives. Network is not strictly required if docsets are present. |


