# 008 Multi-Agent Runbook

你是本项目 `008-mcp-service-benchmark` 的协作 Agent。请严格按以下要求执行并汇报。

## 全局约束

- 工作目录：`/Users/snow/Documents/GitHub/iDocs-mcp`
- 不修改全局 MCP 配置，只使用项目级配置
- 运行结束必须输出：`run_id`、命令、产物路径、失败样本、结论摘要
- 所有结论必须可追溯到 `records.jsonl` / `aggregates.json` / `scores.json` / `report.md`

## Agent A（执行型）

### 任务目标

执行正式 benchmark 轮次并产出完整结果。

### 执行命令

```bash
COLD_SAMPLES=1 WARM_SAMPLES=9 ./scripts/benchmark/run-008-benchmark.sh run-20260320-full-validated
```

### 必交付

1. `run_id`
2. 产物路径：
   - `specs/008-mcp-service-benchmark/artifacts/results/<run_id>/records.jsonl`
   - `specs/008-mcp-service-benchmark/artifacts/results/<run_id>/aggregates.json`
   - `specs/008-mcp-service-benchmark/artifacts/results/<run_id>/scores.json`
   - `specs/008-mcp-service-benchmark/artifacts/results/<run_id>/format-readiness.json`
   - `specs/008-mcp-service-benchmark/artifacts/results/<run_id>/report.md`
3. 执行摘要（成功率、总耗时、异常数）

## Agent B（审计型）

### 任务目标

审计“内容真实性与完整性”链路是否闭环。

### 检查范围（基于 Agent A 的 `run_id`）

- `records.jsonl`
- `artifacts/normalized/<run_id>/`
- `artifacts/assertions/<run_id>/`
- `aggregates.json`
- `scores.json`

### 审计规则

1. 每条 `records.jsonl` 必须有：
   - `normalized_evidence_ref`
   - `assertion_ref`
   - `claim_rate` / `slot_rate`
   - `claim_breakdown` / `slot_breakdown`
   - `needs_review` / `scored_sample`
2. `assertion` 文件内容必须与 `record` 对应字段一致
3. 聚合中的 `avg_claim_rate` / `avg_slot_rate` / `scored_sample_count` / `needs_review_count` 必须与原始记录可复算一致
4. 若发现不一致，列出 sample 级别问题清单（`target + scenario + attempt`）

### 必交付

- 审计通过/不通过
- 不一致样本清单（如有）
- 修复建议（如有）

## Agent C（报告型）

### 任务目标

输出可发布的审核结论。

### 输入

- Agent A 的结果文件
- Agent B 的审计结论

### 输出要求

1. 总分排名 + 分维度排名（`Accuracy/Completeness/Efficiency/Token/Stability/Diagnosability`）
2. `Agent Format Readiness` 结论（按任务类型）
3. 真实性证据链说明：  
   结论 -> record -> assertion -> normalized/raw evidence 的反查路径
4. `needs_review` 样本影响说明
5. 最终建议：
   - 日常查询首选
   - 深度阅读首选
   - 低上下文成本首选
   - 故障定位首选

## 统一回报格式（所有 Agent）

- Agent Name:
- run_id:
- Commands:
- Artifacts:
- Failed Samples:
- Key Findings (5-10 lines):
