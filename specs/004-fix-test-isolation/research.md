# Research: 测试稳定性与网络隔离

## 决策 1：默认测试与网络集成测试分离
- **Decision**: 默认测试不访问网络，网络集成测试通过显式开关启用。
- **Rationale**: 外部服务不可控，默认测试需要可复现与离线可用。
- **Alternatives considered**:
  - 始终运行网络集成测试 → 不稳定且难以在 CI/离线环境通过。

## 决策 2：集成测试启用开关
- **Decision**: 以环境变量控制（例如 `IDOCS_INTEGRATION_TESTS=1` 才执行网络用例）。
- **Rationale**: 与 Swift Testing 的条件执行机制兼容，易于在 CI 中配置。
- **Alternatives considered**:
  - 基于命令行参数或单独的测试目标 → 维护成本更高。

## 决策 3：Apple 文档在线端点构造规则
- **Decision**: 为搜索与技术目录使用已验证的端点规则，避免通用拼接导致的 404。
- **Rationale**: 现有统一拼接策略无法覆盖 search/index 等特殊路径。
- **Alternatives considered**:
  - 继续使用单一 URL 构造函数 → 404 失败无法解决。

## 决策 4：第三方 DocC 抓取的可替换网络层
- **Decision**: 第三方 DocC 抓取支持注入可替代的网络层，单测用 Mock。
- **Rationale**: 外部站点可能 403/429，单元测试必须可离线稳定。
- **Alternatives considered**:
  - 继续直连外部站点 → 单测不稳定，无法满足 SC-001。
