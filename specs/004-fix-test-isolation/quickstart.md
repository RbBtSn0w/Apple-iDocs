# Quickstart: 测试稳定性与网络隔离

## 默认测试（不访问网络）

```bash
# 默认测试：不访问外部网络

./scripts/tuist-silent.sh test
```

## 集成测试（需要显式开启）

```bash
# 启用网络集成测试（环境变量方式）

IDOCS_INTEGRATION_TESTS=1 ./scripts/tuist-silent.sh test
```

```bash
# 启用网络集成测试（过滤器方式）

swift test --filter IntegrationTests
```

## 说明
- 默认测试不依赖外部网络，适用于离线与 CI 环境
- 集成测试用于验证真实在线行为，可能因外部服务不可用而失败
- 使用 `swift test --filter IntegrationTests` 时视为集成模式
