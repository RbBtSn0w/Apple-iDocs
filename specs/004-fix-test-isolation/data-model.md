# Data Model: 测试稳定性与网络隔离

## 实体

### 测试模式 (TestMode)
- **描述**: 标识测试运行是否允许访问外部网络。
- **属性**:
  - `mode`: `default` | `integration`
  - `networkEnabled`: Bool

### 集成测试开关 (IntegrationSwitch)
- **描述**: 显式启用网络集成测试的配置入口。
- **属性**:
  - `key`: 环境变量名
  - `enabledValue`: 触发集成测试的值

### 外部文档源 (ExternalDocSource)
- **描述**: 第三方 DocC 文档来源，用于集成验证或 Mock 替代。
- **属性**:
  - `url`: 文档入口地址
  - `availability`: 可用性状态（可达/不可达）
