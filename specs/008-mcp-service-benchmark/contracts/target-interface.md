# Contract: Benchmark Target Interface

## Scope

本合同定义 `idocs` CLI、`apple-docs-mcp`、`apple-doc-mcp`、`sosumi.ai` 四个目标在 008 基准评测中的统一接入要求、最小可用探测标准和成功/失败判定边界。

## Target Set

- `idocs-cli`
- `apple-docs-mcp`
- `apple-doc-mcp`
- `sosumi-ai`

所有外部服务都必须通过项目级配置接入，禁止依赖全局 MCP 设置。

## Minimal Validation Contract

每个目标都必须支持一条最小验证请求，用于证明：
- 目标可被当前项目环境发现
- 目标可被独立调用
- 返回结果可被识别为成功或可诊断失败

最小验证请求必须记录：
- `targetId`
- `request`
- `status`
- `durationMs`
- `callCount`
- `rawEvidenceRef`

## Shared vs Extended Capability Contract

### Shared Capability Tasks
- 必须适用于全部 4 个目标
- 使用完全相同的输入文本或路径
- 结果参与基础总分

### Extended Capability Tasks
- 仅适用于部分目标
- 必须声明“不纳入基础总分”的原因
- 结果单列展示，不得污染共享能力总分

## Outcome Semantics

允许的统一结果状态：
- `success`
- `failure`
- `partial`
- `not-applicable`

### `not-applicable`
- 仅允许用于扩展能力任务，或明确不属于共享能力范围的场景
- 必须提供原因
- 不得被隐式折算为失败

## Error Categorization

所有失败都必须映射到统一错误分类，至少包括：
- `timeout`
- `network`
- `not_found`
- `invalid_input`
- `service_unavailable`
- `rate_limited`
- `internal`

## Cold / Warm Sampling Contract

- 冷启动样本：执行环境重置后运行
- 热启动样本：保留同轮本地缓存、连接复用和会话态运行
- 每个 `目标 x 共享任务` 至少 10 个样本

## Evidence Contract

每条目标调用至少要保留以下证据之一：
- 原始输出
- 结构化摘要
- 错误日志
- 官方参考证据链接

若某目标被宣称“更快”“更稳定”“更适合 agent 使用”，必须能追溯到对应样本和证据记录。
