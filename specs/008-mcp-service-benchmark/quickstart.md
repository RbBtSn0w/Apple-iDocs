# Quickstart: Validate Project-Scoped MCP Benchmark Environment

## 1) Prepare Project Environment

1. 确认当前分支为 `008-mcp-service-benchmark`
2. 确认使用项目级 MCP 配置，而不是修改任何全局 MCP 设置
3. 准备网络前提、必要账号或密钥，并记录环境说明
4. 记录本轮测试的缓存目录、临时目录和证据输出目录

## 2) Build Local CLI

```bash
tuist install
./scripts/tuist-silent.sh build iDocs
./scripts/tuist-silent.sh run idocs --help
```

## 3) Validate Four Targets Minimum Availability

按项目文档配置以下 4 个目标：
- `idocs` CLI
- `apple-docs-mcp`
- `apple-doc-mcp`
- `sosumi.ai`

对每个目标执行最小验证请求并记录：
- 是否可访问
- 是否返回最小可用结果
- 若失败，是否可诊断

## 4) Run Shared Capability Smoke Tasks

至少执行以下 3 类共享任务：
- `exact-search`
- `fetch`
- `error`

对四个目标使用完全相同的输入，确认统一记录字段能够生成：
- 执行状态
- 调用次数
- 输出长度
- token 可观测性
- 证据引用

## 5) Validate Cold / Warm Sampling

每个冷启动样本前都执行环境重置：
- 重启目标进程
- 清理项目级缓存
- 记录状态隔离步骤

然后对至少一条共享任务执行：
- 1 次冷启动样本
- 多次热启动样本

确认可以区分并记录：
- `cold`
- `warm`
- `duration_ms`
- `call_count`
- `avg_token_per_call`
- `total_token_per_task`

## 6) Validate Evidence and Rubric

确认以下内容可被追溯：
- 原始输出或摘要证据
- 官方参考证据
- 准确性与完整性 checklist
- 可诊断性等级
- 格式可消费性字段

## 7) Validate Statistical Output

对于每个 `目标 x 共享任务`，确认可生成：
- `sample_count`
- `success_rate`
- `p50`
- `p90`
- `p99` 或 `insufficient_sample`
- `stddev`

## 8) Re-run for Repeatability

在同一套任务和 rubric 下重新执行第二轮，确认：
- 字段结构不变
- 评分规则不变
- 可与首轮并列比较

## 9) Expected Outcome

- 四个目标均在项目级环境中可访问或可诊断失败
- 共享能力总分与扩展能力结果分离
- 事实记录、评分结果、格式分析和统计输出可追溯
- benchmark 结果可以被不同评估者按同一 rubric 复核
