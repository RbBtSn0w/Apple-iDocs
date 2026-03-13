# Feature Specification: 提高项目可测试性与单元测试覆盖率

**Feature Branch**: `002-improve-test-coverage`  
**Created**: 2026-03-13  
**Status**: Draft  
**Input**: User description: "因为单元测试的覆盖率低，不满足整体质量。 需要新增技术需求完成项目重构， 支持单元测试的覆盖率。"

## Clarifications

### Session 2026-03-13
- Q: 需要明确 12 种核心 DocC 节点的具体清单以确保 100% 覆盖可验证。 → A: declarations, parameters, properties, paragraph, aside, list, table, heading, codeListing, image, link, section
- Q: 需要明确 Mock 实体在每次测试前如何重置状态以确保隔离性。 → A: 所有 Mock 实体必须实现 reset() 方法，并在测试框架的 beforeEach 中调用。
- Q: 为了确保能够测试各种失败路径，需要预定义一组 Mock 必须支持的核心错误。 → A: noPermission, diskFull, networkTimeout, invalidResponse, fileNotFound
- Q: 需要明确 CI 门禁的具体环境配置。 → A: CI 门禁环境锁定为：macOS 14 (Sonoma), Xcode 15.4 / Swift 6.0
- Q: 是否在 Functional Requirements 中增加 FR-010 以强制要求 CI 失败时自动导出诊断产物（.xcresult/日志）？ → A: 不增加，依赖 CI 界面控制台输出。
- Q: 是否强制要求核心组件在测试时必须注入全新的 Mock 实例，而非共享全局实例？ → A: 强制要求：每个测试用例必须使用独立的 Mock 实例，禁止使用全局/单例 Mock。

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 核心模块重构以支持依赖注入 (Priority: P1)

为了提高代码的可测试性，开发者需要重构目前与外部系统（如网络 API、文件系统、Xcode 路径）紧耦合的核心模块。通过引入协议（Protocols）和依赖注入（Dependency Injection），使得这些模块可以在测试环境下被 Mock 或 Fake 替代，从而实现对边界情况的全面覆盖。

**Why this priority**: 紧耦合是目前覆盖率低（尤其是 iDocsServer 和部分 Tools）的根本原因。如果不解决可测试性架构问题，增加测试将事倍功半。

**Independent Test**: 可通过重构 `AppleJSONAPI` 或 `XcodeLocalDocs` 并在不发起真实网络/磁盘请求的情况下编写并通过 10 个以上针对边界情况（如 500 错误、磁盘满）的测试来验证。

**Acceptance Scenarios**:

1. **Given** 一个需要访问网络的工具, **When** 在测试环境中注入一个返回模拟数据的 Mock 网络层, **Then** 工具应能正确 handle 模拟数据而不产生任何真实网络流量。
2. **Given** 重构后的模块, **When** 检查其公共接口, **Then** 所有依赖项（如 Session, FileManager）均可通过构造函数或属性注入。

---

### User Story 2 - 提升核心逻辑与边界情况的覆盖率 (Priority: P1)

在具备可测试架构的基础上，为项目中的业务逻辑、数据解析、缓存淘汰策略等核心算法补充单元测试。目标是覆盖所有已识别的边缘情况，确保系统在极端输入下依然稳定。

**Why this priority**: 核心逻辑的正确性直接决定了项目的整体质量。目前 `DocCRenderer` 和部分 Tool 的覆盖率较低，存在未知的逻辑缺陷风险。

**Independent Test**: 通过运行 `swift test --enable-code-coverage` 并生成报告，验证指定模块的覆盖率达到成功标准。

**Acceptance Scenarios**:

1. **Given** `DocCRenderer` 模块, **When** 针对各种 DocC 节点类型（包含异常嵌套）编写测试用例, **Then** 该模块的行覆盖率应显著提升（>80%）。
2. **Given** 缓存淘汰逻辑, **When** 模拟并发读写和满容量场景, **Then** 测试应能稳定复现并验证 LRU 行为。

---

### User Story 3 - 自动化覆盖率门禁与报告 (Priority: P2)

建立自动化的测试质量门禁，每次代码提交后自动计算覆盖率并在 CI 中展示。如果覆盖率低于预设阈值，构建应标记为失败。

**Why this priority**: 确保覆盖率在未来开发中不会回退，将质量意识融入开发流程。

**Independent Test**: 在本地模拟一次低覆盖率的代码提交，验证 CI 流程是否能正确拦截并报错。

**Acceptance Scenarios**:

1. **Given** 配置好的 CI 脚本, **When** 运行完整测试套件, **Then** 自动生成 HTML 格式的覆盖率可视化报告。
2. **Given** 预设的 80% 覆盖率门禁, **When** 提交的新代码导致总覆盖率降至 75%, **Then** 构建流水线应触发失败。

---

### Edge Cases

- **并发测试冲突**: 多个异步测试同时操作共享的磁盘缓存 Mock 时是否会发生竞争？
- **深度递归渲染**: `DocCRenderer` 处理超过 50 层嵌套 of DocC JSON 时是否会触发堆栈溢出且有相应测试覆盖？
- **网络超时与重试**: 当 Mock 模拟连续 2 次失败后第 3 次成功时，重试逻辑是否按预期执行？
- **环境路径依赖**: 测试代码是否能完全脱离开发者的 `~/Library` 路径依赖，实现“开箱即运行”？

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系统 MUST 定义统一的 `NetworkSession` 和 `FileSystem` 协议，以抽象 `URLSession` 和 `FileManager`。
- **FR-002**: 核心组件（`AppleJSONAPI`, `XcodeLocalDocs`, `DiskCache`）MUST 支持构造函数注入上述抽象协议。
- **FR-003**: 系统 MUST 提供标准化的 `MockDataTransport` 用于模拟以下核心错误：noPermission, diskFull, networkTimeout, invalidResponse, fileNotFound。
- **FR-004**: 单元测试 MUST 覆盖以下 12 种核心 DocC 节点类型：declarations, parameters, properties, paragraph, aside, list, table, heading, codeListing, image, link, section。
- **FR-005**: 测试套件 MUST 包含针对 `iDocsServer` 启动参数解析和 Transport 切换的逻辑验证。
- **FR-006**: 系统 MUST 在 `Sources/` 下实现逻辑，避免在 `Sources/` 中出现对 `Tests/` 模块的引用。
- **FR-007**: 系统 MUST 支持通过命令行参数或配置文件定义测试覆盖率的最低合格阈值。
- **FR-008**: 所有 Mock 实体 MUST 实现统一的 `reset()` 方法，并确保每个测试用例使用独立的 Mock 实例，严禁共享全局/单例 Mock，以确保测试状态的绝对隔离。
- **FR-009**: 系统 MUST 在指定的 CI 环境（macOS 14 Sonoma, Xcode 15.4）下执行全量测试门禁。

### Key Entities *(include if feature involves data)*

- **测试 Mock (Test Mock)**: 代表一个模拟的外部服务，具有可编程的行为（预设返回值、模拟延迟、抛出特定异常）。
- **覆盖率报告 (Coverage Report)**: 代表测试执行后的统计结果，包含行覆盖、函数覆盖、分支覆盖等指标。
- **可注入组件 (Injectable Component)**: 项目中支持依赖注入的类或 Actor，能够根据环境切换真实或模拟依赖。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 核心算法模块（Cache, Rendering, Utils）的行覆盖率 MUST 达到 **90%** 以上名列清单中的节点。
- **SC-002**: 整体项目（排除 main 入口）的总行覆盖率 MUST 达到 **80%** 以上。
- **SC-003**: 单元测试套件在 10 次连续运行中 MUST 保持 **100% 确定性通过率**，严禁使用自动重试掩盖竞争条件。
- **SC-004**: 所有外部 IO 操作（网络、磁盘）在单元测试阶段 MUST 被 **100% 隔离**，无需网络连接即可运行全量测试。
- **SC-005**: 生成一份覆盖率可视化报告，清晰展示每个文件的覆盖盲点。
