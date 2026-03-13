# 功能需求质量检查清单: Swift 原生 Apple 文档 MCP 服务器

**Purpose**: 验证 spec.md 和 plan.md 中需求的完整性、清晰度、一致性和可衡量性
**Created**: 2026-03-13
**Feature**: [spec.md](../spec.md) | [plan.md](../plan.md)
**Depth**: Standard | **Audience**: Reviewer (PR) | **Focus**: MCP 工具接口、数据层架构、非功能需求

## 需求完整性 (Requirement Completeness)

- [ ] CHK001 - 7 个 MCP 工具是否都定义了完整的输入参数、输出格式和错误响应？ [Completeness, Spec §FR-007]
- [ ] CHK002 - `search_docs` 工具的通配符匹配语义是否明确定义（`*` 匹配零个或多个字符、`?` 匹配单个字符）？ [Completeness, Spec §FR-001]
- [ ] CHK003 - 三层数据回落逻辑中，每层之间的切换条件是否完整定义（何时判定"未命中"）？ [Completeness, Spec §FR-002]
- [ ] CHK004 - `xcode_docs` 工具的 `list` 模式返回的信息字段是否明确列出？ [Gap, Contracts §7]
- [ ] CHK005 - Xcode 文档缓存路径 (`~/Library/Developer/Xcode/DocumentationCache/`) 的子目录结构是否记录？ [Gap]
- [ ] CHK006 - `fetch_video_transcript` 工具接受的 videoID 格式是否穷举定义（仅 "wwdc{year}-{id}" 还是也接受完整 URL）？ [Completeness, Contracts §6]
- [ ] CHK007 - 当 Xcode 未安装时，系统的整体行为是否定义（仅限于 `xcode_docs` 工具不可用，还是影响其他工具的回落逻辑）？ [Gap]
- [ ] CHK008 - `fetch_external_doc` 工具对第三方 DocC URL 的验证规则是否定义（接受哪些域名/路径模式）？ [Gap, Contracts §5]
- [ ] CHK009 - MCP Server 启动时的初始化流程是否定义（Xcode 文档发现、缓存加载、索引预热等步骤和顺序）？ [Gap]
- [ ] CHK010 - HTTP 传输模式下的会话管理需求是否定义（会话超时、最大并发会话数、会话隔离）？ [Gap, Spec §US-8]

## 需求清晰度 (Requirement Clarity)

- [ ] CHK011 - SC-001 中"2 秒内完成搜索"是否区分了本地搜索与在线搜索的性能目标？ [Clarity, Spec §SC-001]
- [ ] CHK012 - SC-003 中"100% 语义结构保留"的验证方法是否定义（如何量化和比对）？ [Clarity, Spec §SC-003]
- [ ] CHK013 - "毫秒级符号定位"（SC-002 定义为 100ms）与"高频查询"的具体含义是否精确？ [Clarity, Spec §SC-002]
- [ ] CHK014 - FR-015 中"自动切换请求标识重试"的具体策略是否量化（最大重试次数、退避间隔、超时时间）？ [Clarity, Spec §FR-015]
- [ ] CHK015 - FR-016 中"静默回落"的具体行为是否清晰——是完全无日志还是仅不向用户报错但记录日志？ [Ambiguity, Spec §FR-016]
- [ ] CHK016 - "高质量 Markdown"渲染的具体质量标准是否定义（覆盖哪些 DocC 节点类型、哪些可忽略）？ [Clarity, Spec §FR-003]
- [ ] CHK017 - FR-022 "大文件"的阈值是否定义（多大的文件触发内存映射）？ [Ambiguity, Spec §FR-022]
- [ ] CHK018 - "单一可执行文件"（FR-018）是否明确排除了动态链接库依赖（如 libswiftCore.dylib）？ [Clarity, Spec §FR-018]

## 需求一致性 (Requirement Consistency)

- [ ] CHK019 - Spec 中定义了 8 个用户故事但 FR-007 声明为 7 个工具——US-1（搜索）和 US-2（获取文档）是否映射到不同的工具？ [Consistency, Spec §FR-007 vs §US-1/US-2]
- [ ] CHK020 - Data-model 中 `DataSource` 枚举有 3 个值 (xcode/diskCache/remote)，是否与 Spec 中三层回落逻辑完全对齐？ [Consistency, Data-Model §DataSource]
- [ ] CHK021 - Contracts 中 `search_docs` 的 `limit` 默认值为 10，是否与 Spec 中的性能目标一致（返回 10 条结果的响应时间）？ [Consistency, Contracts §1]
- [ ] CHK022 - Plan 中 `MemoryCache` 默认容量 100 条目与 Spec 中的缓存需求（FR-009）是否对齐——100 条目是否足够？ [Consistency, Plan vs Spec §FR-009]
- [ ] CHK023 - Constitution 中"禁止引入额外 Web 框架"与 HTTP 传输模式的 SSE 需求之间是否存在冲突？ [Consistency, Constitution §VI vs Spec §US-8]

## 验收标准质量 (Acceptance Criteria Quality)

- [ ] CHK024 - SC-005 "可执行文件体积不超过 20MB"的基准是否合理——是否基于类似 Swift CLI 工具的实测数据？ [Measurability, Spec §SC-005]
- [ ] CHK025 - SC-006 "自动重试成功率 90%"的测试方法和样本量是否定义？ [Measurability, Spec §SC-006]
- [ ] CHK026 - SC-008 "缓存命中比在线快 10 倍"的基准测量方法是否明确（相同文档、相同网络环境）？ [Measurability, Spec §SC-008]
- [ ] CHK027 - SC-009 "5 秒内完成优雅关闭"是否定义了需要完成的具体收尾工作（缓存持久化、连接断开）？ [Measurability, Spec §SC-009]
- [ ] CHK028 - US-3 的验收场景 4 "毫秒级时间内返回"是否与 SC-002 的 100ms 一致？ [Consistency, Spec §US-3 vs §SC-002]

## 场景覆盖 (Scenario Coverage)

- [ ] CHK029 - 是否定义了"缓存过期但网络不可用"时的降级行为——返回过期数据还是报错？ [Coverage, Edge Case]
- [ ] CHK030 - 是否定义了 LMDB 索引文件损坏时的恢复/降级策略？ [Coverage, Edge Case]
- [ ] CHK031 - 是否定义了 Apple JSON API 格式变更（breaking change）时的检测和降级策略？ [Coverage, Exception Flow]
- [ ] CHK032 - 是否定义了多个 Xcode 版本并存时的文档发现和优先级策略？ [Coverage, Alternate Flow]
- [ ] CHK033 - 是否定义了 `fetch_doc` 返回内容过大（超出 AI 上下文窗口）时的处理策略（截断？摘要？分页？）？ [Coverage, Edge Case, Spec Edge Cases §5]
- [ ] CHK034 - 是否定义了 Spotlight (NSMetadataQuery) 不可用或被用户禁用时的搜索降级方案？ [Coverage, Exception Flow]
- [ ] CHK035 - 是否定义了磁盘缓存目录无写入权限时的错误处理？ [Coverage, Exception Flow]
- [ ] CHK036 - 是否定义了 `fetch_hig` 在 HIG 结构变更后的容错机制？ [Coverage, Exception Flow]

## 非功能需求 (Non-Functional Requirements)

- [ ] CHK037 - 内存使用上限是否定义（LRU 缓存 + mmap 的总内存占用预算）？ [Gap, NFR]
- [ ] CHK038 - 磁盘缓存空间使用上限是否定义（`~/Library/Caches/iDocs/` 的最大占用）？ [Gap, NFR]
- [ ] CHK039 - 日志输出的存储策略是否定义（日志轮转、最大日志文件大小）？ [Gap, Spec §FR-013]
- [ ] CHK040 - 冷启动时间（从进程启动到可接受 MCP 请求）是否有性能目标？ [Gap, NFR]
- [ ] CHK041 - 并发请求处理能力是否定义（HTTP 模式下的最大并发工具调用数）？ [Gap, NFR]
- [ ] CHK042 - 网络请求超时时间是否定义（Apple API、第三方 DocC、WWDC 转录）？ [Gap, NFR]
- [ ] CHK043 - 数据隐私需求是否定义（用户本地文档路径是否出现在日志或 MCP 响应中）？ [Gap, NFR]

## 依赖与假设 (Dependencies & Assumptions)

- [ ] CHK044 - Apple `developer.apple.com/tutorials/data` JSON API 的非公开性质是否在需求中记录为风险？ [Assumption]
- [ ] CHK045 - Xcode 文档缓存路径 `~/Library/Developer/Xcode/DocumentationCache/` 是否在不同 Xcode 版本间稳定？ [Assumption]
- [ ] CHK046 - MCP Swift SDK v0.11.0+ 的 `StatefulHTTPServerTransport` 是否经过生产环境验证？ [Dependency]
- [ ] CHK047 - LMDB C 桥接是否需要 Package.swift 中额外的系统库声明？ [Dependency, Gap]
- [ ] CHK048 - robots.txt 合规要求是否记录了 Apple developer.apple.com 的实际 robots.txt 规则？ [Assumption]

## Notes

- 检查项按在 spec/plan 中的影响范围排序
- `[Gap]` 表示现有规格说明中缺失的需求
- `[Ambiguity]` 表示需要进一步澄清的模糊描述
- `[Assumption]` 表示需要验证的隐含假设
- 完成后使用 `[x]` 标记，并在行内添加发现说明
