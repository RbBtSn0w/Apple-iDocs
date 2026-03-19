# Contract: Evaluation Record Schema

## Purpose

定义 008 基准评测的统一记录字段、枚举语义和可复测约束，防止结果漂移或自由发挥。

## Core Record

每条执行记录必须包含：

| Field | Required | Description |
|------|----------|-------------|
| `run_id` | Yes | 评测轮次标识 |
| `target_id` | Yes | 服务目标标识 |
| `scenario_id` | Yes | 测试任务标识 |
| `attempt_index` | Yes | 样本编号 |
| `sample_class` | Yes | `cold` 或 `warm` |
| `status` | Yes | `success` / `failure` / `partial` / `not-applicable` |
| `started_at` | Yes | 开始时间 |
| `finished_at` | Yes | 结束时间 |
| `duration_ms` | Yes | 总耗时 |
| `call_count` | Yes | 完成任务所需调用次数 |
| `output_length` | Yes | 输出字符数或等价长度 |
| `avg_token_per_call` | No | 单次调用平均 token |
| `total_token_per_task` | No | 完成整任务的累计 token |
| `token_observability` | Yes | `full` / `partial` / `none` |
| `tokenizer_spec` | Yes | 用于估算 token 的统一 tokenizer 规范，默认 `cl100k_base` |
| `driver_profile` | Yes | 本轮执行使用的受控 Driver 配置 |
| `truth_baseline` | Yes | 参考真值对应的 Xcode / SDK / 文档版本锚点 |
| `overfetch_flag` | Yes | 是否发生过度召回或无请求噪音 |
| `error_category` | No | 失败分类 |
| `evidence_refs` | Yes | 证据引用列表 |
| `accuracy_verdict` | Yes | 准确性结论 |
| `completeness_verdict` | Yes | 完整性结论 |
| `reviewer_notes` | No | 评审备注 |

## Format Readiness Fields

共享能力任务必须追加：

| Field | Required | Description |
|------|----------|-------------|
| `format_extractability` | Yes | 结构可提取性，`1/3/5` |
| `format_density` | Yes | 信息密度，`1/3/5` |
| `format_task_fit` | Yes | 任务适配度，`1/3/5` |
| `format_noise` | Yes | 噪声控制，`1/3/5` |
| `format_citability` | Yes | 可引用性，`1/3/5` |
| `format_notes` | Yes | 评分依据 |

## Enumerations

### `token_observability`
- `full`: 可直接读取真实 token
- `partial`: 仅部分调用或部分阶段可观测
- `none`: 不可直接观测，只能估算

### `status`
- `success`: 完成任务且可评分
- `failure`: 未完成任务
- `partial`: 返回部分可用内容但未完整完成任务
- `not-applicable`: 不适用于当前目标，且必须说明原因

### `sample_class`
- `cold`: 经过环境重置
- `warm`: 保留同轮缓存/连接/会话

## Statistical Output Contract

每个 `目标 x 共享任务` 必须能聚合输出：
- `sample_count`
- `success_rate`
- `timeout_rate`
- `mean_duration_ms`
- `p50_duration_ms`
- `p90_duration_ms`
- `p99_duration_ms` 或 `insufficient_sample`
- `stddev_duration_ms`

## Golden Dataset Contract

每条 `scenario_id` 都必须绑定冻结后的标准答案结构：
- `atomic_claims`
- `required_slots`
- `truth_baseline`

评测阶段只能对上述结构进行勾选，不得临时修改。

## Traceability Rules

- 每个分数必须能映射回至少一条执行记录
- 每个执行记录必须能映射回至少一个证据引用
- 每个共享任务的基础总分和格式评分都必须可追溯到字段级原始记录
