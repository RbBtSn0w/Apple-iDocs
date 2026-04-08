# Implementation Plan: 项目级 MCP 接入与四路基准评测

**Branch**: `008-mcp-service-benchmark` | **Date**: 2026-03-19 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/008-mcp-service-benchmark/spec.md`

## Summary

在当前仓库内接入 `idocs` CLI、`apple-docs-mcp`、`apple-doc-mcp`、`sosumi.ai` 四个目标，建立项目级测试环境与统一评测体系。方案以“事实记录优先、评分次之”为核心，补齐共享能力/扩展能力分层、AI agent 输出可消费性评估、统计学有效的性能样本、客观 rubric、缓存隔离与复测可追溯链路，最终产出可重复执行的 benchmark 文档、记录 schema、评分合同与 quickstart。

## Technical Context

**Language/Version**: Swift 6.0（项目设置）+ shell scripts  
**Primary Dependencies**: Tuist, swift-argument-parser, swift-log；外部目标为 `idocs` CLI、`apple-docs-mcp`、`apple-doc-mcp`、`sosumi.ai`  
**Storage**: 规格文档与合同文件；项目级配置文件；项目级缓存与证据记录文件；本地 Xcode 文档缓存  
**Testing**: Swift Testing（`./scripts/tuist-silent.sh test`）+ 脚本化 benchmark/replay 验证  
**Target Platform**: macOS 13+（测试 target 现为 macOS 14+）  
**Project Type**: Swift CLI 项目上的评测系统与文档化合同特性  
**Performance Goals**: 每个共享能力任务对每个目标至少输出 `P50/P90`；当样本量满足条件时输出 `P99`；冷/热启动统计可区分且可复测  
**Constraints**: 非全局 MCP 设置；共享能力总分与扩展能力结果分离；外部服务不可控；不可观测 token 不得伪装为低成本；评审标准需冻结为 rubric  
**Scale/Scope**: 4 个目标、至少 12 条任务、每任务每目标至少 10 次自动化性能样本；产出 `research.md`、`data-model.md`、`contracts/`、`quickstart.md`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. 离线优先**: PASS. 不改变 `idocs` 现有 local-first 检索逻辑；评测中显式记录网络依赖、缓存状态、冷/热隔离，避免把远端不可控缓存误当本地能力。
- **II. 无状态工具设计**: PASS. 每条测试任务要求完整输入、独立执行、无前置会话依赖；多次 tool call 仅作为任务成本的一部分被记录。
- **III. 测试先行**: PASS. 先冻结任务集、记录 schema、统计口径、评分细则和 quickstart，再进入实现与自动化。
- **IV. 可观测性**: PASS. 设计要求产出 `runId`、样本编号、环境重置、错误分类、证据引用、统计结果与 rubric 映射。
- **V. 极简主义**: PASS. 固定比较 4 个目标，不扩展为通用 benchmark 平台；结果文档聚焦共享能力、扩展能力、格式可消费性和真实性证据。
- **VI. Swift 原生优先**: PASS. 复用现有 Swift/Tuist/脚本体系，不引入新的全局运行时或额外 Web 服务。
- **VII. 类型安全**: PASS. 统一记录字段、评分枚举、状态枚举与合同 schema 先建模，再驱动实现，避免 ad-hoc 表格和自由文本。

**Post-design re-check**: PASS. 研究与设计未引入违反 constitution 的新依赖或架构扩张；唯一复杂度上升来自统计样本、rubric 和证据链要求，属于 benchmark 可信度所必需。

## Project Structure

### Documentation (this feature)

```text
specs/008-mcp-service-benchmark/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── target-interface.md
│   ├── evaluation-record-schema.md
│   └── scoring-rubric.md
└── tasks.md
```


### Source Code (repository root)

```text
Sources/
├── iDocs/
│   ├── Commands/
│   ├── DataSources/
│   ├── Tools/
│   └── Utils/
├── iDocsAdapter/
│   ├── Adapters/
│   ├── Models/
│   └── Protocols/
└── iDocsKit/
    └── Utils/

Tests/
├── iDocsTests/
│   ├── IntegrationTests/
│   ├── Mocks/
│   └── TestSupport/
└── iDocsAdapterTests/

scripts/
├── tuist-silent.sh
└── arch-gate.sh
```

**Structure Decision**: 沿用现有单仓库 Swift CLI 分层结构。008 的主要设计产物落在 `specs/008-mcp-service-benchmark/`，后续实现阶段预计通过项目级 MCP 配置、脚本化 benchmark、测试支持和文档合同来完成，不新增独立运行时子系统。

## Complexity Tracking

No constitution violations requiring exception.
