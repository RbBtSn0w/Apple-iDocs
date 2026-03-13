# Research: 提高项目可测试性与单元测试覆盖率

## 1. Actor-Safe Dependency Injection (依赖注入)

### 决策
采用 **构造函数注入 (Constructor Injection)** 结合 **Swift 协议 (Protocols)**。

### 理由
- **线程安全**: Protocols 声明为 `Sendable` 可确保在 Actor 边界安全传输。
- **静态检查**: 编译器确保所有依赖在初始化时就绪，避免运行时错误。
- **无框架依赖**: 遵循 Constitution V (极简主义)，不引入外部 DI 容器。

### 模式示例
```swift
public protocol NetworkSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

public actor AppleJSONAPI {
    private let session: any NetworkSession
    public init(session: any NetworkSession = URLSession.shared) {
        self.session = session
    }
}
```

## 2. 抽象系统级 API (Spotlight & FileSystem)

### 决策
- **FileSystem**: 抽象 `FileManager` 的常用方法（`fileExists`, `contentsOfDirectory`, `removeItem`）。
- **Spotlight**: 抽象 `NSMetadataQuery` 为 `SearchProvider` 协议。

### 理由
- `NSMetadataQuery` 依赖 RunLoop 和全局索引，直接测试极难且不可靠。
- 通过 `SearchProvider` 协议，测试可以模拟“命中”、“未命中”或“索引损坏”等多种状态。

## 3. 自动化覆盖率监测

### 决策
使用 `swift test --enable-code-coverage` 结合 `xcrun llvm-cov`。

### 操作步骤
1. 执行测试并启用覆盖率: `swift test --enable-code-coverage`
2. 获取二进制路径: `swift build --show-bin-path`
3. 生成报告: 
   ```bash
   xcrun llvm-cov report \
     .build/debug/iDocsPackageTests.xctest/Contents/MacOS/iDocsPackageTests \
     -instr-profile=.build/debug/codecov/default.profdata \
     -ignore-filename-regex=".build|Tests"
   ```

### 自动化门禁
编写简单的 Bash 脚本解析 `llvm-cov` 的输出，若总覆盖率低于 80% 则 `exit 1`。

## 4. 备选方案评估

| 方案 | 评价 | 结论 |
|------|------|------|
| **使用 Swift OpenAPI Generator Mock** | 太过重量级，本项目只需简单的 JSON 模拟。 | **拒绝** |
| **SwiftyMocky 等代码生成库** | 需要额外依赖和预处理步骤，违反 Constitution VI。 | **拒绝** |
| **基于子类的 Mock** | 无法处理 Actor，且对 Struct 无效。 | **拒绝** |
| **协议 Mock (当前方案)** | 最灵活，支持 Struct/Class/Actor，零依赖。 | **采纳** |
