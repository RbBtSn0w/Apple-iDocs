# Research: 提高项目可测试性与单元测试覆盖率

## 1. Actor-Safe Dependency Injection (依赖注入)

### 决策
采用 **构造函数注入 (Constructor Injection)** 结合 **Swift 协议 (Protocols)**。

### 理由
- **隔离性**: 通过注入独立实例，确保测试用例之间不共享状态，符合 SC-003。
- **线程安全**: Protocols 声明为 `Sendable` 可确保在 Actor 边界安全传输。
- **重置机制**: 强制实现 `reset()` 方法以清空 Mock 内部的 Stub 数据。

## 2. 模拟系统级错误 (Mocking Strategy)

### 决策
定义强类型 `MockError` 枚举。

### 理由
- 统一模拟 `noPermission`, `diskFull`, `networkTimeout`, `invalidResponse`, `fileNotFound` 等关键路径。
- 通过协议抽象 `FileManager` (FileSystem) 和 `URLSession` (NetworkSession)，实现 100% 的错误路径注入。

## 3. 自动化覆盖率门禁 (CI Pipeline)

### 决策
使用 `swift test --enable-code-coverage` 结合自定义 Bash 脚本进行硬拦截。

### 操作流程
1. 执行测试: `swift test --enable-code-coverage`
2. 聚合结果: 使用 `xcrun llvm-cov report`
3. 门禁检查: 脚本解析 "TOTAL" 行的 "Cover" 百分比，若 < 80% 则中断 CI 流程。

## 4. 备选方案评估

| 方案 | 评价 | 结论 |
|------|------|------|
| **Vapor Test 框架** | 仅限于网络层，对本地 Xcode 文档无能为力。 | **拒绝** |
| **SwiftyMocky** | 需要 Sourcery 生成代码，增加编译复杂度。 | **拒绝** |
| **原生协议 Mock** | 最轻量级，完全符合 Constitution V (极简主义)。 | **采纳** |
