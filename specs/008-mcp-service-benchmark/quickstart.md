# Quickstart: Validate Project-Scoped MCP Benchmark Environment

## 1) Prepare Project Environment

1. 确认当前分支为 `008-mcp-service-benchmark`
2. 确认使用项目级 MCP 配置，而不是修改任何全局 MCP 设置
3. 准备网络前提、必要账号或密钥，并记录环境说明
4. 记录本轮测试的缓存目录、临时目录和证据输出目录
5. 记录本轮 pinning 信息：`driver_profile`、`tokenizer_spec`、`truth_baseline`
6. 可选：设置 `LLM_JUDGE_CMD` 启用边界样本二次评审（未设置时仅规则引擎评审）

## 2) Build Local CLI

```bash
tuist install
./scripts/tuist-silent.sh build iDocs
./scripts/tuist-silent.sh run idocs --help
```

执行约束：
- `./scripts/tuist-silent.sh test` 与 `./scripts/benchmark/run-008-benchmark.sh` 不要并发运行
- 两者默认共用 `~/Library/Developer/Xcode/DerivedData/iDocs-codex`
- 若必须并发，请先显式设置独立的 `IDOCS_DERIVED_DATA_PATH`

## 3) Validate Four Targets Minimum Availability

先执行：

```bash
./scripts/benchmark/bootstrap-project-mcp.sh
./scripts/benchmark/probe-targets.sh
```

按项目配置验证 4 个目标：
- `idocs-cli`
- `apple-docs-mcp`
- `apple-doc-mcp`
- `sosumi-ai`

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
- `tokenizer_spec`
- `driver_profile`

## 6) Validate Evidence and Rubric

确认以下内容可被追溯：
- 原始输出或摘要证据
- 结构化抽取证据（normalized output）
- 断言证据（claim/slot breakdown）
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

命令示例：

```bash
./scripts/benchmark/run-008-benchmark.sh run-20260319-a
./scripts/benchmark/run-008-benchmark.sh run-20260319-b
./scripts/benchmark/compare-runs.sh run-20260319-a run-20260319-b
```

快速冒烟可使用：

```bash
SHARED_LIMIT=1 ./scripts/benchmark/run-008-benchmark.sh run-20260319-real-smoke
```

## 9) Expected Outcome

- 四个目标均在项目级环境中可访问或可诊断失败
- 共享能力总分与扩展能力结果分离
- 事实记录、评分结果、格式分析和统计输出可追溯
- benchmark 结果可以被不同评估者按同一 rubric 复核

## 10) Operator Checklist

- 确认 `specs/008-mcp-service-benchmark/fixtures/golden-dataset.json` 已冻结
- 确认 `specs/008-mcp-service-benchmark/fixtures/tokenizer-spec.json` 为 `cl100k_base`
- 确认 `specs/008-mcp-service-benchmark/fixtures/driver-profile.json` 已锁定执行策略
- 确认 `specs/008-mcp-service-benchmark/fixtures/truth-baseline.json` 已声明 SDK 版本锚点
- 确认每个“更快/更省/更稳定”结论都有证据链

## 11) Troubleshooting

- 目标探测失败：先执行 `./scripts/benchmark/reset-target-state.sh all` 后重试
- 统计项缺失 `p99`：检查样本数是否达到 10
- token 争议：检查是否将 `token_observability=none` 误当作实测
- 版本偏差：若命中新 API，按 `version skew` 规则标记，不直接判定工具失效

## 12) Validated Smoke Output (run-20260319-smoke)

已验证产物路径：

- `specs/008-mcp-service-benchmark/artifacts/results/target-probes.json`
- `specs/008-mcp-service-benchmark/artifacts/results/run-20260319-smoke/records.jsonl`
- `specs/008-mcp-service-benchmark/artifacts/results/run-20260319-smoke/aggregates.json`
- `specs/008-mcp-service-benchmark/artifacts/results/run-20260319-smoke/scores.json`
- `specs/008-mcp-service-benchmark/artifacts/results/run-20260319-smoke/format-readiness.json`
- `specs/008-mcp-service-benchmark/artifacts/results/run-20260319-smoke/report.md`

协议驱动冒烟产物（真实 MCP JSON-RPC）：

- `specs/008-mcp-service-benchmark/artifacts/results/run-20260319-real-smoke/records.jsonl`
- `specs/008-mcp-service-benchmark/artifacts/results/run-20260319-real-smoke/report.md`

新增可追溯产物：
- `specs/008-mcp-service-benchmark/artifacts/normalized/<run-id>/...`
- `specs/008-mcp-service-benchmark/artifacts/assertions/<run-id>/...`

最近一次本地冒烟验证：
- `specs/008-mcp-service-benchmark/artifacts/results/run-20260408-smoke/records.jsonl`
- `specs/008-mcp-service-benchmark/artifacts/results/run-20260408-smoke/aggregates.json`
- `specs/008-mcp-service-benchmark/artifacts/results/run-20260408-smoke/scores.json`
- `specs/008-mcp-service-benchmark/artifacts/results/run-20260408-smoke/format-readiness.json`
- `specs/008-mcp-service-benchmark/artifacts/results/run-20260408-smoke/report.md`
