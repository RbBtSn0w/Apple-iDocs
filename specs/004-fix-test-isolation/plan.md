# Implementation Plan: 测试稳定性与网络隔离

**Branch**: `004-fix-test-isolation` | **Date**: 2026-03-16 | **Spec**: [specs/004-fix-test-isolation/spec.md](spec.md)
**Input**: Feature specification from `/specs/004-fix-test-isolation/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

目标是让默认测试在离线/不稳定网络下仍可稳定通过，同时提供显式开关运行网络集成测试；并修正 Apple 文档搜索与技术目录的在线端点构造规则，避免 404；第三方 DocC 抓取支持可替换网络层以便单测可离线执行。

## Technical Context

**Language/Version**: Swift 6.2+  
**Primary Dependencies**: modelcontextprotocol/swift-sdk, swift-service-lifecycle, swift-log, Tuist  
**Storage**: 文件系统缓存（~/Library/Caches），本功能不新增持久化存储  
**Testing**: Swift Testing（`Testing`），`tuist test` / `swift test`  
**Target Platform**: macOS 13+  
**Project Type**: MCP Server / CLI  
**Performance Goals**: N/A（不新增性能目标）  
**Constraints**: 默认测试离线可运行；集成测试需显式开启；符合离线优先与测试先行原则  
**Scale/Scope**: 单仓库，改动集中在测试策略与网络访问层

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- 离线优先：通过（默认测试不依赖网络）
- 无状态工具设计：通过（不改变工具调用约束）
- 测试先行：通过（补齐测试分层与集成测试门禁）
- 可观测性：通过（不削弱日志要求）
- 极简主义：通过（不新增工具数量）
- Swift 原生优先：通过（保持 Swift 原生实现）
- 类型安全：通过（不引入 Any/AnyObject）

## Project Structure

### Documentation (this feature)

```text
specs/004-fix-test-isolation/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
Sources/
└── iDocs/
    ├── DataSources/
    ├── Tools/
    └── Utils/

Tests/
└── iDocsTests/
    ├── IntegrationTests/
    └── Mocks/

scripts/
```

**Structure Decision**: 单工程结构，核心改动集中在 `Sources/iDocs/` 与 `Tests/iDocsTests/`。
