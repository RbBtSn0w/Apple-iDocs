# Data Model: 项目级 MCP 接入与四路基准评测

## Overview

008 的数据模型围绕“可复测评估系统”构建，而不是围绕某个单一服务的运行时对象构建。核心目标是统一描述测试目标、测试任务、执行记录、证据、评分和环境隔离步骤。

## Entities

### ServiceTarget
- **Purpose**: 描述被纳入比较的单个目标。
- **Fields**:
  - `id: String`，唯一标识，如 `idocs-cli`
  - `name: String`
  - `kind: cli | mcp`
  - `scope: project-local`
  - `requiresNetwork: Bool`
  - `tokenObservability: full | partial | none`
  - `capabilities: [String]`
- **Validation**:
  - `id` 全局唯一
  - `kind` 仅允许 `cli` 或 `mcp`
  - `tokenObservability` 仅允许声明枚举值

### TestScenario
- **Purpose**: 定义一条统一输入的验证任务。
- **Fields**:
  - `id: String`
  - `name: String`
  - `category: shared | extended`
  - `taskType: exact-search | fuzzy-search | fetch | understand | error | long-content`
  - `input: String`
  - `expectedEvidenceType: official-page | official-docc | execution-behavior`
  - `applicableTargets: [ServiceTarget.id]`
  - `requiredChecklist: [String]`
- **Validation**:
  - `shared` 任务必须适用于全部 4 个目标
  - `extended` 任务必须声明为何不纳入基础总分

### EvaluationRun
- **Purpose**: 记录某一轮完整评测。
- **Fields**:
  - `runId: String`
  - `startedAt: DateTime`
  - `operator: String`
  - `environment: String`
  - `baselineVersionSet: [String: String]`
  - `notes: String?`
- **Validation**:
  - `runId` 唯一
  - `environment` 必须包含网络/缓存/平台前提摘要

### TaskExecution
- **Purpose**: 单个目标在单条任务上的一次执行样本。
- **Fields**:
  - `runId: EvaluationRun.id`
  - `targetId: ServiceTarget.id`
  - `scenarioId: TestScenario.id`
  - `attemptIndex: Int`
  - `sampleClass: cold | warm`
  - `status: success | failure | partial | not-applicable`
  - `startedAt: DateTime`
  - `finishedAt: DateTime`
  - `durationMs: Int`
  - `callCount: Int`
  - `outputLength: Int`
  - `avgTokenPerCall: Int?`
  - `totalTokenPerTask: Int?`
  - `tokenObservability: full | partial | none`
  - `errorCategory: String?`
  - `retryable: Bool?`
  - `evidenceRefs: [ReferenceEvidence.id]`
- **Validation**:
  - `durationMs >= 0`
  - `callCount >= 0`
  - `not-applicable` 必须提供原因
  - `sampleClass` 必须与环境重置记录一致

### ReferenceEvidence
- **Purpose**: 为事实和结论提供可复核依据。
- **Fields**:
  - `id: String`
  - `sourceType: official-page | official-docc | raw-output | log | screenshot | summary`
  - `locator: String`
  - `checksumOrVersion: String?`
  - `capturedAt: DateTime`
- **Validation**:
  - `official-page` 与 `official-docc` 必须可指向权威来源
  - `raw-output` 必须能映射回对应 `TaskExecution`

### RubricScore
- **Purpose**: 记录总评分模型中的维度得分。
- **Fields**:
  - `accuracy: Int`
  - `completeness: Int`
  - `efficiency: Int`
  - `cost: Int`
  - `stability: Int`
  - `diagnosability: Int`
  - `notes: String?`
- **Validation**:
  - 各项分数均在允许范围内
  - 分值必须可映射到 checklist 或统计依据

### FormatReadinessScore
- **Purpose**: 记录 AI agent 输出可消费性评分。
- **Fields**:
  - `extractability: Int`
  - `density: Int`
  - `taskFit: Int`
  - `noise: Int`
  - `citability: Int`
  - `notes: String?`
- **Validation**:
  - 评分采用 `1 / 3 / 5`
  - 必须附带文字依据和原始输出片段

### EnvironmentResetStep
- **Purpose**: 记录冷启动样本前执行的环境重置动作。
- **Fields**:
  - `stepId: String`
  - `type: process | cache | state`
  - `requiredFor: cold | all`
  - `status: pending | completed | skipped`
  - `notes: String?`
- **Validation**:
  - 冷启动样本至少包含 `process` 与 `cache` 两类重置

## Supporting Structures

### ScoreWeights
- `accuracy = 35`
- `completeness = 20`
- `efficiency = 15`
- `cost = 10`
- `stability = 10`
- `diagnosability = 10`

### FormatWeights
- `extractability = 30`
- `density = 25`
- `taskFit = 20`
- `noise = 15`
- `citability = 10`

## State Transitions

### Scenario Lifecycle
1. 定义 `TestScenario`
2. 标记为 `shared` 或 `extended`
3. 绑定参考证据与检查清单
4. 对每个适用目标生成执行样本
5. 汇总事实记录、统计指标和 rubric 结果

### Execution Lifecycle
1. 执行环境重置
2. 启动目标并发送任务输入
3. 记录原始输出、调用次数和 token 边界
4. 绑定官方证据
5. 计算准确性/完整性/诊断性/格式评分
6. 汇总到比较报告
