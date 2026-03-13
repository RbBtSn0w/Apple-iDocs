# Quickstart: 运行覆盖率测试

## 1. 环境准备
确保已安装 Xcode 15.0+ 和 Swift 6.0+。

## 2. 运行测试并启用覆盖率
在项目根目录下执行：
```bash
swift test --enable-code-coverage
```

## 3. 查看简易报告
```bash
xcrun llvm-cov report \
  $(swift build --show-bin-path)/iDocsPackageTests.xctest/Contents/MacOS/iDocsPackageTests \
  -instr-profile=$(swift build --show-bin-path)/codecov/default.profdata \
  -ignore-filename-regex=".build|Tests"
```

## 4. 查看详细可视化报告 (HTML)
```bash
xcrun llvm-cov show \
  $(swift build --show-bin-path)/iDocsPackageTests.xctest/Contents/MacOS/iDocsPackageTests \
  -instr-profile=$(swift build --show-bin-path)/codecov/default.profdata \
  -format=html \
  -output-dir=coverage_report \
  -ignore-filename-regex=".build|Tests"

open coverage_report/index.html
```
