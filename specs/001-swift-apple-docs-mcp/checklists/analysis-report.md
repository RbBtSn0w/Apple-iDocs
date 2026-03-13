# Specification Analysis Report (v3)

**Feature**: Swift 原生 Apple 文档 MCP 服务器
**Branch**: `001-swift-apple-docs-mcp` | **Date**: 2026-03-13 | **Revision**: v3
**Artifacts Analyzed**: spec.md, plan.md, tasks.md, data-model.md, contracts/, research.md, constitution.md

> [!NOTE]
> v3 修订：在 v2 基础上修正 Metrics 口径定义、SC Coverage 三级拆分、I3 条件约束方案、U1 降级为 INFO。

---

## Findings

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|:--------:|-------------|---------|----------------|
| G1 | Coverage Gap | **CRITICAL** | spec §FR-018, §SC-005 → tasks.md | FR-018"单一可执行文件、零运行时依赖"+ SC-005"≤20MB"无产物验收任务（依赖扫描、体积门禁、静态链接验证） | Phase 11 新增 Distribution Validation 任务 |
| G2 | Coverage Gap | **CRITICAL** | spec §SC-001/002/006/008/009 → tasks.md | 5 个可量化 SC 无基准验证任务。T049 仅功能验证，无性能断言 | 新增性能基准测试任务，至少覆盖 SC-001/002/009 |
| G3 | Coverage Gap | **HIGH** | spec §SC-004 → tasks.md | SC-004"离线 100% 可用"无显式验证任务（需断网环境下已缓存功能全量可用） | 新增离线功能验收任务或在 T045 端到端测试中增加离线场景 |
| G4 | Coverage Gap | **HIGH** | spec §FR-009 → data-model, plan | LRU 容量上限和淘汰行为仅在 plan 标注"默认 100 条目"，spec 无需求定义 | 在 spec FR-009 补充容量策略需求 |
| G5 | Coverage Gap | **HIGH** | spec §SC-003 → tasks T019 | SC-003"100% 语义结构保留"缺少验证手段 — 无 golden file 对比测试 | 在 T019 中补充预期 Markdown 输出的 golden file 对比 |
| G6 | Coverage Gap | **MEDIUM** | spec §SC-010 → tasks T046 | T046 实现日志推送，但无验证任务断言关键事件（文档发现、缓存命中/未中、API 回落、错误降级）必须产生日志 | 在 T045 端到端测试中增加日志断言 |
| G7 | Coverage Gap | **LOW** | spec §FR-006 → tasks T024 | FR-006 (Spotlight) 在 T024 中已显式声明，但缺少独立验证用例 | 在 T023 (XcodeLocalDocsTests) 中增加 Spotlight 专项用例 |
| I1 | Inconsistency | **MEDIUM** | spec §FR-007 vs §US-1~US-8 | FR-007"7 个工具"但有 8 个 US。US-8 是传输层非工具，措辞易混淆 | FR-007 附注说明 US-8 是传输配置 |
| I2 | Inconsistency | **MEDIUM** | plan §MemoryCache vs data-model §CacheEntry | plan"O(1) 查找/淘汰"，但 data-model 未明确 LRU 键类型约束 | data-model 补充键类型和容量策略 |
| I3 | Inconsistency | **MEDIUM** | contracts §7 vs tasks | `xcode_docs` 的 `symbol` 标为 required，但 `action=list` 时无意义 | 改为条件约束：`action=search` → `symbol` required；`action=list` → `symbol` forbidden |
| D1 | Duplication | **MEDIUM** | spec §FR-002 vs §FR-016 | "三层回落"(机制) 与"静默回落不报错"(行为) 语义重叠 | FR-002 聚焦机制；FR-016 聚焦用户行为，交叉引用 |
| A1 | Ambiguity | **MEDIUM** | spec §FR-015 | "自动切换请求标识重试"未量化。research.md 已定义 3 次+指数退避，spec 未反映 | 将 research 决策回写 spec |
| A2 | Ambiguity | **MEDIUM** | spec §FR-016 + Constitution §IV | "不报错"是否包含不记日志？与可观测性 MUST 潜在冲突 | 明确为"不向用户报错，MUST 记录 warning 日志" |
| A3 | Ambiguity | **MEDIUM** | spec §FR-022 | "大文件"阈值未定义 | 定义阈值（如 >1MB 触发 mmap） |
| A4 | Ambiguity | **MEDIUM** | spec §FR-005 | "毫秒级符号定位"不可判定，需交叉引用 SC-002 | FR-005 直接绑定 `p95 ≤ 100ms` |
| A5 | Ambiguity | **MEDIUM** | spec §US-1 AC4 | "速度显著更快"主观不可测 | 改为"缓存命中 ≥10x 加速 (SC-008)" |
| A6 | Ambiguity | **MEDIUM** | spec Edge Cases §5 | "文档过大"列为边界情况但无 FR 或任务 | 添加截断/摘要策略 FR |
| U1 | Underspec | **INFO** | research.md §4 → tasks T010 | research 提到 `NSFileCoordinator` 并发文件访问，tasks 未覆盖。属追溯完整性建议，非规格级问题 | 可在 T010 实现时自行判断，不阻塞实施 |
| U2 | Underspec | **LOW** | spec §US-8 → tasks T043/T044 | HTTP 模式会话超时、最大并发数未定义 | 在 spec 或 contracts 补充参数 |
| U3 | Underspec | **LOW** | spec.md 第 5 行 | 状态仍为 `Draft`，已走完全流程 | 更新为 `Ready for Implementation` |
| U4 | Underspec | **LOW** | tasks T047/T048 | "创建 README"和"代码清理"缺少 DoD | 补充完成判定标准 |
| D2 | Duplication | **LOW** | spec §US-3 AC4 vs §SC-002 | "毫秒级"与"100ms"同一能力措辞不一致 | 统一量化表述 |
| D3 | Duplication | **LOW** | contracts §1 vs spec §FR-001 | 通配符支持重复描述 | 保持一致即可 |

---

## Coverage Summary

### FR Coverage

| Requirement | Has Task? | Task IDs | Notes |
|------------|:---------:|----------|-------|
| FR-001 搜索+通配符 | ✅ | T017 | — |
| FR-002 三层回落 | ✅ | T017, T027 | 与 FR-016 需明确边界 (D1) |
| FR-003 DocC→Markdown | ✅ | T020 | — |
| FR-004 Xcode 本地读取 | ✅ | T024 | — |
| FR-005 毫秒级定位 | ✅ | T024 | FR 应绑定阈值 (A4) |
| FR-006 Spotlight 搜索 | ✅ | T024 | 已显式声明，建议增加专项测试 (G7) |
| FR-007 7 个工具 | ✅ | T017-T044 | — |
| FR-008 磁盘缓存+TTL | ✅ | T010 | — |
| FR-009 LRU 内存缓存 | ✅ | T009 | 容量策略 spec 未定义 (G4) |
| FR-010 Stdio 连接 | ✅ | T013, T042 | T042 含 Stdio 测试 |
| FR-011 HTTP 连接 | ✅ | T042, T043, T044 | T042 测试 + T043 参数解析 + T044 HTTP Transport |
| FR-012 优雅关闭 | ✅ | T013 | ServiceLifecycle |
| FR-013 结构化日志 | ✅ | T013, T046 | — |
| FR-014 MCP 日志推送 | ✅ | T046 | — |
| FR-015 403/429 重试 | ✅ | T011 | spec 未量化 (A1) |
| FR-016 静默回落 | ✅ | T017, T027 | 与日志原则需澄清 (A2) |
| FR-017 语义化错误 | ✅ | 各 Tool 任务 | — |
| FR-018 单二进制 | ⚠️ | T001 | 无产物验收任务 (G1) |
| FR-019 HIG | ✅ | T031, T032, T033 | T031 测试 + T032/T033 实现 |
| FR-020 第三方 DocC | ✅ | T035, T036, T037 | T035 测试 + T036/T037 实现 |
| FR-021 WWDC 转录 | ✅ | T039, T040 | T039 测试 + T040 实现 |
| FR-022 内存映射 | ✅ | T024 | 阈值未定义 (A3) |
| FR-023 技术目录 | ✅ | T028, T029 | T028 测试 + T029 实现 |

### SC Coverage

| Success Criteria | Has Task? | Task IDs | Verification Method |
|-----------------|:---------:|----------|---------------------|
| SC-001 搜索 ≤2s | ❌ Missing | — | 缺基准测试 (G2) |
| SC-002 本地 ≤100ms | ❌ Missing | — | 缺基准测试 (G2) |
| SC-003 100% 结构保留 | ⚠️ Partial | T019 | 有测试但缺 golden file 对比 (G5) |
| SC-004 离线 100% 可用 | ❌ Missing | — | 缺离线场景验证 (G3) |
| SC-005 体积 ≤20MB | ❌ Missing | — | 缺门禁任务 (G1) |
| SC-006 重试 ≥90% | ❌ Missing | — | 缺基准测试 (G2) |
| SC-007 7 工具独立调用 | ⚠️ Partial | T045, T049 | 可覆盖但需明确自动化断言 |
| SC-008 缓存 ≥10x | ❌ Missing | — | 缺基准测试 (G2) |
| SC-009 关闭 ≤5s | ❌ Missing | — | 缺基准测试 (G2) |
| SC-010 全量结构化日志 | ⚠️ Partial | T046 | 实现有但缺验证断言 (G6) |

**SC Coverage 口径**: Full (实现+验证均完备): 0/10 · Partial (有实现或任务但验证不足): 3/10 · Missing (无对应任务): 7/10

---

## Constitution Alignment

| Principle | Status | Notes |
|-----------|:------:|-------|
| I. 离线优先 | ⚠️ | 回落已覆盖，但 SC-004 离线验收缺失 (G3) |
| II. 无状态工具 | ✅ | 7 工具均独立 |
| III. 测试先行 | ✅ | 已修复：所有 US 包含测试任务 |
| IV. 可观测性 | ⚠️ | FR-016"不报错"需澄清 (A2)；SC-010 验证缺失 (G6) |
| V. 极简主义 | ✅ | 7 工具，单二进制 |
| VI. Swift 原生优先 | ✅ | 无额外 Web 框架 |
| VII. 类型安全 | ✅ | 全量 Codable |

---

## Metrics

| Metric | Value |
|--------|-------|
| Total Requirements | 23 (FR) + 10 (SC) = 33 |
| Total Tasks | 49 (T001-T049) |
| FR Coverage (Full) | 22/23 (95.7%) — Full = 实现+验收均完备；FR-018 有实现无验收 |
| SC Coverage | Full: 0/10 · Partial: 3/10 · Missing: 7/10 |
| CRITICAL Issues | **2** (G1, G2) |
| HIGH Issues | 3 (G3, G4, G5) |
| MEDIUM Issues | 11 (G6, I1-I3, D1, A1-A6) |
| LOW Issues | 6 (G7, U2-U4, D2, D3) |
| INFO Issues | 1 (U1) |
| Total Findings | **23** |

---

## Next Actions

### 🔴 实施前必须修复 (CRITICAL — 阻塞 /speckit.implement)

1. **G1**: Phase 11 新增 Distribution Validation 任务（`otool -L` 扫描、体积 ≤20MB 断言、Mach-O static 校验）
2. **G2**: 新增性能基准测试任务，至少覆盖 SC-001/002/009；其余通过集成测试阈值断言

### 🟡 建议实施前处理 (HIGH)

3. **G3**: 在 T045 端到端测试中增加离线场景（断网环境已缓存功能全量可用）
4. **G5**: T019 补充 golden file 渲染对比测试
5. **G4**: spec FR-009 补充 LRU 容量策略需求

### 🟢 实施过程中收敛 (MEDIUM/LOW)

6. **A2** 优先（Constitution IV 合规）
7. **G6** 在 T045 中增加日志断言
8. **U3** 启动前更新 spec 状态
9. 其余项在对应 Phase 实施时修正

---

## Revision Log

### v2 修正 (2026-03-13)

| 项 | v1 → v2 | 修正原因 |
|----|---------|---------|
| U1 定位 | `plan → tasks` → `research.md §4 → tasks` | `NSFileCoordinator` 仅出现在 research.md，plan.md 无此内容 |
| G3 (原) | FR-006 隐含, **HIGH** → 重编号 G7, **LOW** | T024 已显式声明 Spotlight NSMetadataQuery |
| FR-011 映射 | 仅 T044 → T042, T043, T044 | 遗漏了测试任务和参数解析任务 |
| SC-004 | 未列出 → 新增 G3, **HIGH** | 离线验收是 Constitution I 的直接体现 |
| SC-010 | 未列出 → 新增 G6, **MEDIUM** | 实现任务有但缺验证断言 |
| SC-007 | 未列出 → Coverage 表补充 | 需明确自动化断言方式 |
| FR-019~023 | 映射不含测试任务 → 补充完整链路 | US4-US8 已补充测试任务 |

### v3 修正 (2026-03-13)

| 项 | v2 → v3 | 修正原因 |
|----|---------|---------|
| Metrics 口径 | FR 22/23 无定义, SC 2/10 → FR 标注 Full 定义; SC 拆分 Full/Partial/Missing | 口径混用导致数字误导 |
| I3 建议 | `symbol` 可选 → 条件约束: search→required, list→forbidden | 简单可选不够精确，条件约束更贴合业务语义 |
| U1 严重度 | LOW → INFO | 属 research 决策追溯完整性建议，非规格级阻塞问题 |
| SC Coverage | 2/10 (20%) → Full: 0/10, Partial: 3/10, Missing: 7/10 | 二元比例无法区分部分覆盖与完全缺失 |

