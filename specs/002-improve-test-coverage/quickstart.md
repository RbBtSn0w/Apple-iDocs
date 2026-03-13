# Quickstart: 运行覆盖率测试与质量验证

## 1. 运行测试套件
在项目根目录下执行以下命令，启用覆盖率收集并执行全量单元测试：
```bash
swift test --enable-code-coverage
```

## 2. 生成行覆盖率报告 (Summary)
使用 `llvm-cov` 生成针对核心模块的简要报告：
```bash
xcrun llvm-cov report \
  $(swift build --show-bin-path)/iDocsPackageTests.xctest/Contents/MacOS/iDocsPackageTests \
  -instr-profile=$(swift build --show-bin-path)/codecov/default.profdata \
  -ignore-filename-regex=".build|Tests"
```

## 3. 生成可视化 HTML 报告
导出完整的 HTML 报告以识别代码中的盲点：
```bash
xcrun llvm-cov show \
  $(swift build --show-bin-path)/iDocsPackageTests.xctest/Contents/MacOS/iDocsPackageTests \
  -instr-profile=$(swift build --show-bin-path)/codecov/default.profdata \
  -format=html \
  -output-dir=coverage_report \
  -ignore-filename-regex=".build|Tests"

# 查看报告
open coverage_report/index.html
```

## 4. 零 Flaky 验证
根据 SC-003 准则，连续运行 10 次确保无随机失败：
```bash
for i in {1..10}; do swift test || break; done
```
