# Implementation Plan: 提高项目可测试性与单元测试覆盖率

**Branch**: `002-improve-test-coverage` | **Date**: 2026-03-13 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/002-improve-test-coverage/spec.md`

## Summary

通过架构重构（引入协议抽象与依赖注入），解决目前核心组件与系统 IO（网络、磁盘、Xcode 路径）的强耦合问题。引入标准化 Mock 机制，实现 100% 离线测试环境，并将项目总行覆盖率提升至 80% 以上，核心模块（Rendering, Cache, Utils）提升至 90% 以上。

## Technical Context

**Language/Version**: Swift 6.2+, Structured Concurrency  
**Primary Dependencies**: `modelcontextprotocol/swift-sdk` (v0.11.0+), `swift-server/swift-service-lifecycle`, `apple/swift-log`  
**Storage**: `Foundation.FileManager` (抽象为 FileSystem 协议), `Data(contentsOf:options:.mappedIfSafe)`  
**Testing**: Swift Testing (TDD), `swift test --enable-code-coverage`, `llvm-cov` for reporting  
**Target Platform**: macOS (Spotlight, Xcode DocumentationCache)
**Project Type**: CLI (MCP Server)  
**Performance Goals**: 本地符号定位 p95 ≤ 100ms, 搜索响应 ≤ 2s  
**Constraints**: 单二进制文件体积 < 20MB, 离线 100% 可用 (三层回落逻辑)  
**Scale/Scope**: 重构 4 个核心数据源与缓存组件，新增 30+ 边界情况测试用例

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Decision/Action |
|-----------|:------:|-----------------|
| I. 离线优先 | ✅ PASS | 重构目标即为实现 100% 离线单元测试，不影响生产环境三层逻辑。 |
| II. 无状态 | ✅ PASS | 重构不涉及工具状态变更，仅优化内部依赖注入。 |
| III. 测试先行 | ✅ PASS | 本功能是 Constitution III 的深度实践，所有重构均由测试驱动。 |
| IV. 可观测性 | ✅ PASS | 重构需确保 `swift-log` 在 Mock 环境下依然可用且可验证。 |
| V. 极简主义 | ✅ PASS | 采用轻量级协议抽象，避免过度设计或引入重量级 DI 框架。 |
| VI. 原生优先 | ✅ PASS | 使用原生 Protocol 与 Generics 解决依赖问题，不引入外部 Mock 库。 |
| VII. 类型安全 | ✅ PASS | 严格利用 Swift 协议关联类型确保类型安全。 |

## Project Structure

### Documentation (this feature)

```text
specs/002-improve-test-coverage/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── checklists/
│   └── requirements.md  # Specification Quality Checklist
└── tasks.md             # Phase 2 output (to be created by /speckit.tasks)
```

### Source Code (repository root)

```text
Sources/iDocs/
├── Protocols/           # [NEW] 抽象协议定义 (NetworkSession, FileSystem)
├── DataSources/         # 重构后的数据源 (支持注入)
├── Cache/               # 重构后的缓存层 (支持注入)
├── Rendering/           # 增加覆盖率的渲染引擎
└── iDocsServer.swift    # 增加启动参数解析测试

Tests/iDocsTests/
├── Mocks/               # [NEW] 通用 Mock 实现
├── IntegrationTests/    # 增加覆盖率的集成测试
└── UnitTests/           # 核心逻辑单元测试
```

**Structure Decision**: 采用单项目结构 (Swift Package)。在 `Sources/iDocs/Protocols/` 下新增抽象层，在 `Tests/iDocsTests/Mocks/` 下集中管理模拟对象。

## Complexity Tracking

> 无 Constitution Check 违规，无需记录。
