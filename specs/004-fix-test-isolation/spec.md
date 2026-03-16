# Feature Specification: 测试稳定性与网络隔离

**Feature Branch**: `004-fix-test-isolation`  
**Created**: 2026-03-16  
**Status**: completed
**Input**: User description: "问题描述需求（现状）...验收标准（可验证）"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 默认测试稳定可复现 (Priority: P1)

开发者在本地或 CI 运行默认测试命令时，不依赖任何外部网络或第三方服务，也不会因网络不可达而失败。

**Why this priority**: 稳定的默认测试是开发迭代与 CI 可信度的基础。

**Independent Test**: 断开网络环境后运行默认测试命令，仍能稳定通过。

**Acceptance Scenarios**:

1. **Given** 开发者未显式开启网络测试, **When** 运行默认测试命令, **Then** 所有测试通过且不发起外部网络请求
2. **Given** 外部服务不可达, **When** 运行默认测试命令, **Then** 测试不因网络错误失败

---

### User Story 2 - 显式启用网络集成测试 (Priority: P1)

当需要验证真实在线行为时，开发者可通过显式开关启用网络集成测试。

**Why this priority**: 集成验证仍然必要，但必须与默认测试解耦。

**Independent Test**: 设置显式开关后运行测试，网络相关用例被执行。

**Acceptance Scenarios**:

1. **Given** 显式开启网络集成测试, **When** 运行测试命令, **Then** 网络相关用例被执行
2. **Given** 未开启显式开关, **When** 运行测试命令, **Then** 网络相关用例被跳过

---

### User Story 3 - Apple 文档在线访问一致性 (Priority: P2)

开发者发起文档搜索与技术目录访问时，在线接口应按照已验证规则构造，避免 404。

**Why this priority**: 这是核心功能路径，线上失败会直接影响搜索与浏览体验。

**Independent Test**: 在可用网络环境下执行搜索与技术目录调用，返回有效结果。

**Acceptance Scenarios**:

1. **Given** 输入有效查询, **When** 发起文档搜索, **Then** 不因 URL 构造问题返回 404
2. **Given** 请求技术目录, **When** 发起在线访问, **Then** 返回有效分类列表

---

### User Story 4 - 第三方 DocC 测试可离线执行 (Priority: P2)

第三方 DocC 抓取在单元测试中应支持替换网络层，确保离线稳定运行。

**Why this priority**: 外部站点不可控，单测需可复现。

**Independent Test**: 使用可替代网络层的方式运行 DocC 单测并稳定通过。

**Acceptance Scenarios**:

1. **Given** 使用可替代的网络层, **When** 运行 DocC 单元测试, **Then** 在离线环境中稳定通过
2. **Given** 外部站点不可用, **When** 运行默认测试, **Then** 不产生失败

---

### User Story 5 - 测试策略文档清晰 (Priority: P3)

项目文档应明确区分单元测试与网络集成测试，并说明如何启用集成测试。

**Why this priority**: 确保团队一致理解测试分层与执行方式。

**Independent Test**: 阅读文档即可明确默认测试范围与集成测试启用方式。

**Acceptance Scenarios**:

1. **Given** 开发者阅读测试文档, **When** 查找执行方式, **Then** 可清晰区分默认测试与集成测试

---

### Edge Cases

- 当显式开关开启但网络不可用时，测试应如何呈现结果与诊断信息？
- 当外部服务返回 403/429 时，集成测试的失败信息是否足够可诊断？
- 当在线接口规则调整时，如何避免默认测试被破坏？

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系统 MUST 将默认测试与网络集成测试分离，默认测试不依赖外部网络
- **FR-002**: 系统 MUST 提供显式开关以启用网络集成测试
- **FR-003**: 系统 MUST 使用已验证的在线接口构造规则，避免搜索与技术目录请求返回 404
- **FR-004**: 系统 MUST 允许第三方 DocC 抓取在测试中替换网络层，以支持离线执行
- **FR-005**: 系统 MUST 在文档中说明测试分层与集成测试启用方式
- **FR-006**: 系统 MUST 在集成测试失败时提供清晰可诊断的错误信息

### Key Entities *(include if feature involves data)*

- **测试模式 (Test Mode)**: 标识当前运行的是默认测试还是网络集成测试
- **集成测试开关 (Integration Switch)**: 用于显式启用网络集成测试的配置入口
- **外部文档源 (External Doc Source)**: 第三方 DocC 数据来源，用于集成验证

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 在无网络环境下运行默认测试命令，测试全部通过且不访问外部网络
- **SC-002**: 显式开启集成测试后，网络相关用例才会执行
- **SC-003**: 搜索与技术目录请求不再因 URL 构造错误返回 404
- **SC-004**: 第三方 DocC 的单元测试可在替代网络层条件下稳定通过
- **SC-005**: 文档中明确记录测试分层与启用方式
