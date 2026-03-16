# iDocs-mcp Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-03-16

## Active Technologies
- Swift 6.2+, Structured Concurrency + `modelcontextprotocol/swift-sdk` (v0.11.0+), `swift-server/swift-service-lifecycle`, `apple/swift-log` (002-improve-test-coverage)
- `Foundation.FileManager` (抽象为 FileSystem 协议), `Data(contentsOf:options:.mappedIfSafe)` (002-improve-test-coverage)
- Swift 6.2+ + Tuist 4.x, MCP SDK (v0.11.0+), Swift Service Lifecycle (v2.3.0+), Swift Log (003-tuist-migration)
- N/A (Manifest-based) (003-tuist-migration)
- Swift 6.2+ (Enabling Full Concurrency) + Tuist 4.158.2, ArgumentParser (for CLI target), Foundation (005-three-layer-architecture)
- DiskCache (Local File System with `flock` cross-process locking) (005-three-layer-architecture)

- Swift 6.2 + `modelcontextprotocol/swift-sdk`, `swift-service-lifecycle`, `swift-log` (001-swift-apple-docs-mcp)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for Swift 6.2

## Code Style

Swift 6.2: Follow standard conventions

## Recent Changes
- 005-three-layer-architecture: Added Swift 6.2+ (Enabling Full Concurrency) + Tuist 4.158.2, ArgumentParser (for CLI target), Foundation
- 003-tuist-migration: Added Swift 6.2+ + Tuist 4.x, MCP SDK (v0.11.0+), Swift Service Lifecycle (v2.3.0+), Swift Log
- 002-improve-test-coverage: Added Swift 6.2+, Structured Concurrency + `modelcontextprotocol/swift-sdk` (v0.11.0+), `swift-server/swift-service-lifecycle`, `apple/swift-log`


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
