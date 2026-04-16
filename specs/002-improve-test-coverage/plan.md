# Implementation Plan: 提高项目可测试性与单元测试覆盖率

> Historical context: this plan was written before the repository was explicitly narrowed to the `idocs` CLI-only product direction. References to MCP server runtime or MCP-specific dependencies below describe the superseded context, not the current shipped runtime.

**Branch**: `002-improve-test-coverage` | **Date**: 2026-03-13 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/002-improve-test-coverage/spec.md`

## Summary

通过架构重构（引入协议抽象与依赖注入），彻底解决目前核心组件与系统 IO（网络、磁盘、Xcode 路径）的强耦合问题。实施“零 Flaky 容忍”策略，确保 100% 确定性测试通过。目标是将项目总行覆盖率提升至 80% 以上，核心模块（Rendering, Cache, Utils）提升至 90% 以上，并覆盖 12 种核心 DocC 节点类型。

## Technical Context

**Language/Version**: Swift 6.2+, Structured Concurrency  
**Primary Dependencies**: `modelcontextprotocol/swift-sdk` (v0.11.0+), `swift-server/swift-service-lifecycle`, `apple/swift-log`  
**Storage**: `Foundation.FileManager` (抽象为 FileSystem 协议), `Data(contentsOf:options:.mappedIfSafe)`  
**Testing**: Swift Testing (TDD), `swift test --enable-code-coverage`, `llvm-cov` for reporting (Zero Flaky Tolerance)
**Target Platform**: macOS 14 (Sonoma), Xcode 15.4 / Swift 6.0 (Locked CI Environment)
**Project Type**: CLI (MCP Server)  
**Performance Goals**: 100% 离线测试运行, 全量测试执行时间 < 30s  
**Constraints**: 单二进制文件体积 < 20MB, Mock 实体必须支持 `reset()` 并在每个用例中使用独立实例  
**Scale/Scope**: 重构 4 个核心数据源与缓存组件，覆盖 12 种核心 DocC 节点，新增 30+ 边界测试用例

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Decision/Action |
|-----------|:------:|-----------------|
| I. 离线优先 | ✅ PASS | 重构目标即为实现 100% 离线单元测试，确保逻辑验证不依赖网络。 |
| II. 无状态 | ✅ PASS | 重构确保工具调用无副作用，Mock 状态随测试周期重置。 |
| III. 测试先行 | ✅ PASS | 本功能是 Constitution III 的核心实践，所有重构均由测试驱动。 |
| IV. 可观测性 | ✅ PASS | 确保 `swift-log` 在 Mock 环境下依然可验证关键路径。 |
| V. 极简主义 | ✅ PASS | 采用轻量级协议抽象，严禁引入重量级 DI 或 Mock 框架。 |
| VI. 原生优先 | ✅ PASS | 使用 Swift 原生 Protocol 与 Generics 实现依赖注入。 |
| VII. 类型安全 | ✅ PASS | 明确定义 MockError 枚举，避免使用通用 Error 类型。 |

## Project Structure

### Documentation (this feature)

```text
specs/002-improve-test-coverage/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── internal-protocols.md # Phase 1 output
├── checklists/
│   └── testability.md   # Specification Quality Checklist
└── tasks.md             # Phase 2 output (to be created by /speckit.tasks)
```

### Source Code (repository root)

```text
Sources/iDocs/
├── Protocols/           # [NEW] 抽象协议定义 (NetworkSession, FileSystem, SearchProvider)
├── DataSources/         # 重构后的数据源 (支持注入)
├── Cache/               # 重构后的缓存层 (支持注入)
├── Rendering/           # 增加覆盖率的渲染引擎 (覆盖 12 种核心节点)
└── iDocsServer.swift    # 增加启动参数解析逻辑测试

Tests/iDocsTests/
├── Mocks/               # [NEW] 通用 Mock 实现 (独立实例, 显式 reset)
├── IntegrationTests/    # 增加覆盖率的集成测试
└── UnitTests/           # 核心逻辑单元测试
```

**Structure Decision**: 采用单项目结构 (Swift Package)。在 `Sources/iDocs/Protocols/` 下新增抽象层，在 `Tests/iDocsTests/Mocks/` 下集中管理模拟对象。

## Complexity Tracking

> 无 Constitution Check 违规，无需记录。
