# Contract: Scoring Rubric

## Purpose

冻结 008 的评分规则，确保不同评估者、不同时间复测时仍能按一致标准给分。

## Total Score Weights

| Dimension | Weight |
|------|--------|
| Accuracy | 35 |
| Completeness | 20 |
| Efficiency | 15 |
| Token / Context Cost | 10 |
| Stability | 10 |
| Diagnosability | 10 |

## Accuracy Rubric

按 atomic claims 命中率评分。每条任务必须在 benchmark 执行前由 Golden Dataset 预生成可核对事实，例如：
- API 名称
- 签名
- 参数说明
- 平台信息
- 限制条件
- 来源路径

每项标记为：
- `correct`
- `incorrect`
- `missing`
- `unverifiable`

准确性分数来自冻结后的 claims 命中情况，不允许评测时重写 claim 粒度或分母。

## Completeness Rubric

按任务类型定义 required slots：

- `search`: 标题、路径/标识、摘要或片段、来源线索
- `fetch`: 标题、正文、签名、参数、平台、来源
- `understand`: 概念说明、关键约束、来源、任务相关细节
- `error`: 明确错误类别、原因、建议
- `long-content`: 分段结构、关键内容保留、来源

完整性分数来自命中率映射，不允许只用自由文本描述。

## Golden Dataset Rule

- Atomic Claims 和 Required Slots 必须在任务执行前冻结
- 评测者只能勾选 `correct / incorrect / missing / unverifiable`
- 不允许在评测阶段新增 claims、拆分 claims 或合并 slots

## Efficiency Rubric

主指标：
- `Total Token per Task`
- `call_count`
- `duration_ms`

同等任务下，优先比较整任务总成本，而不是单次返回大小。

若某目标发生 over-fetching 或 unsolicited information，且显著增加整任务调用成本、上下文成本或后续清洗成本，则必须在效率或成本维度中扣分，而不是仅在格式维度扣分。

## Stability Rubric

必须基于统计结果：
- `success_rate`
- `timeout_rate`
- `p50`
- `p90`
- `stddev`

如果样本不足以支持目标统计项，必须显式标记，不得补主观分。

## Diagnosability Rubric

| Score Level | Meaning |
|------|---------|
| `0` | 静默失败或超时，无有效诊断信息 |
| `1` | 只有通用错误，如 HTTP 500 / Unknown error |
| `2` | 有具体错误原因，如 `not found`、`invalid input` |
| `3` | 有具体原因且包含可执行建议、候选路径或重试条件 |

最终诊断分数必须映射到该等级。

## Format Readiness Rubric

### Weights

| Dimension | Weight |
|------|--------|
| Extractability | 30 |
| Density | 25 |
| Task Fit | 20 |
| Noise | 15 |
| Citability | 10 |

### Score Values

| Value | Meaning |
|------|---------|
| `1` | 明显不适合当前任务 |
| `3` | 可用，但需清洗或补推理 |
| `5` | 高度适合，几乎可直接消费 |

### Required Evidence

格式评分必须至少绑定以下事实中的若干项：
- 原始输出片段
- 输出总长度或估算 token
- 是否含明显导航、front matter、重复内容
- 是否保留来源标识
- 是否能稳定抽出标题、参数、链接、来源

## Reporting Rules

最终报告必须同时输出：
- 基础总分
- 维度分解
- 格式可消费性结果
- 不可观测项说明

不得把“格式分高”解释为“内容更准确”或“功能更完整”。
不得把 over-fetching 风险仅视为格式问题而完全排除在主评分之外。
