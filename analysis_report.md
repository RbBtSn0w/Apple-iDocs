# Apple Docs MCP 三项目对比分析

三个开源项目均旨在让 AI 助手访问 Apple 开发者文档, 但在**架构理念、数据获取、内容处理、功能覆盖**上差异显著。

---

## 一、项目概览

| 维度 | apple-doc-mcp | apple-docs-mcp | sosumi.ai |
|------|--------------|----------------|-----------|
| **作者** | MightyDillah | kimsungwhee | NSHipster (nshipster) |
| **npm 包名** | `apple-doc-mcp-server` | `@kimsungwhee/apple-docs-mcp` | `@nshipster/sosumi` |
| **运行模式** | 本地 stdio MCP | 本地 stdio MCP | **Cloudflare Worker + HTTP/SSE MCP + CLI** |
| **依赖量** | 轻量 (axios + MCP SDK) | 中等 (cheerio + zod + MCP SDK) | 较重 (hono + cheerio + robots-parser + wrangler) |
| **MCP 工具数** | 6 | **15** | 4 |
| **代码规模** | ~5K 行 | ~15K+ 行 | ~8K+ 行 |

---

## 二、数据获取方式

### apple-doc-mcp
- **数据源**: `developer.apple.com/tutorials/data/{path}.json` (Apple 内部 JSON API)
- **方式**: 直接 axios GET, **单一硬编码 User-Agent** (Chrome UA)
- **特点**: 要求**先选择 technology, 再搜索**, 有状态的工作流

### apple-docs-mcp
- **数据源**: 同样使用 Apple JSON API, 还结合了 HTML 搜索页面解析 (cheerio)
- **方式**: 自定义 HTTP Client, **12+ UserAgent 池** (Chrome/Firefox/Safari/Edge), 支持 random/sequential/smart 三种轮换策略
- **特点**: 无状态, 每个工具独立工作; **HTML 搜索结果解析**弥补了 JSON API 搜索能力的不足

### sosumi.ai
- **数据源**: 同样使用 Apple JSON API, 但区分**框架首页** (`/index/{framework}`) vs **单页** (`/{path}.json`)
- **方式**: 原生 [fetch()](file:///Users/snow/Documents/GitHub/iDocs-mcp/sosumi.ai/src/lib/reference/fetch.ts#9-54) (Cloudflare Worker 运行时), **26 个 Safari 系 UserAgent 随机选取**
- **特点**: 额外支持 **HIG (Human Interface Guidelines)** 和**外部 Swift-DocC 站点**代理; 不仅是 MCP, 还是**独立的 HTTP 服务 + CLI**

> [!IMPORTANT]
> 三者都使用 Apple 未公开的 `tutorials/data` JSON API, 这不是官方公开 API, 存在被封锁或变更的风险。`sosumi.ai` 在这方面考虑最周全, 有 `robots.txt` 遵守机制和限速。

---

## 三、缓存策略对比

| 策略 | apple-doc-mcp | apple-docs-mcp | sosumi.ai |
|------|--------------|----------------|-----------|
| **内存缓存** | 简单 Map 缓存 | TTL + 容量限制 (多等级) | 无 |
| **文件缓存** | `.cache/` 目录持久化 JSON | 无 | 无 |
| **缓存粒度** | Framework / Symbol / Technologies 分别缓存 | API (30min) / Search (10min) / Framework (1h) / Technologies (2h) 不同 TTL | 仅靠 Cloudflare 的 HTTP 缓存层 |
| **离线能力** | 首次获取后可离线 | 会话内可用, 重启丢失 | 必须在线 |

**分析:**
- `apple-doc-mcp` 的**文件缓存**是独特优势, 但**没有 TTL 过期**, 可能导致数据过时
- `apple-docs-mcp` 的 TTL 策略最精细, 但纯内存, **重启后冷启动**
- `sosumi.ai` 完全无应用层缓存, 依赖 Cloudflare CDN 边缘缓存

---

## 四、内容处理与渲染

### apple-doc-mcp (渲染质量 2/5)
- 仅提取 `title`, `abstract`, `platforms`, `kind`, `url` 等字段做简单拼接
- 不解析 `primaryContentSections`, 不渲染代码声明
- 适合**搜索发现**, 不适合深度阅读

### apple-docs-mcp (渲染质量 3/5)
- 完整解析 `declarations`, `parameters`, `content` 等 section
- 支持 Related APIs / References / Similar APIs / Platform Analysis 等增强分析
- 缺点: 大量 `any` 类型断言, 代码块缺少换行符, 部分 URL 硬编码 SwiftUI

### sosumi.ai (渲染质量 5/5)
- **740 行专用渲染器**, 覆盖全部 DocC JSON 节点类型
- 支持: declarations, parameters, **properties**, content, tables, aside (映射为 GitHub callout), orderedList/unorderedList, codeListing, images, emphasis/strong, relationship sections, topic sections, see also, index content
- **链接重写**: 所有 `doc://` identifier 和 `/documentation/` 路径自动改写为 sosumi.ai URL
- **递归深度保护** (50 层 content / 20 层 inline)
- **Front matter**: 含 title, description, source URL, timestamp

---

## 五、功能覆盖

| 功能 | apple-doc-mcp | apple-docs-mcp | sosumi.ai |
|------|:---:|:---:|:---:|
| API 文档获取 | Yes | Yes | Yes |
| 文档搜索 | 框架内搜索 | **全站搜索** | 全站搜索 |
| Technology 浏览 | Yes | Yes (含分类过滤) | No |
| Framework 符号搜索 | 本地索引 + 通配符 | 通配符 + 类型过滤 | No |
| Related/Similar APIs | No | Yes | No (但文档内含 See Also) |
| Platform 兼容分析 | No | Yes | No (文档内含平台信息) |
| WWDC 视频搜索 | No | **本地 35MB JSON** | No |
| WWDC 视频详情/转录 | No | 离线数据 | 在线抓取 |
| HIG 人机界面指南 | No | No | **Yes** |
| 外部 Swift-DocC 代理 | No | No | **Yes** |
| Sample Code 浏览 | No | Yes | No |
| Documentation Updates | No | Yes | No |
| CLI 工具 | No | No | Yes |
| HTTP API | No | No | Yes |
| Chrome 扩展 | No | No | Yes (社区) |
| 多语言 README | No | Yes (日/韩/中) | No |

---

## 六、优缺点总结

### apple-doc-mcp

| 优点 | 缺点 |
|------|------|
| **极轻量**, 仅 2 个依赖 | 渲染质量最差, 输出信息量少 |
| **文件缓存**, 支持离线复用 | **有状态工作流**, 必须先 `choose_technology` |
| 简单直接, 易理解 | 单一 User-Agent, 容易被封 |
| 通配符搜索 (`*`, `?`) | 功能最少, 无 WWDC/HIG/搜索 |
| | 无缓存过期, 数据可能过时 |

### apple-docs-mcp

| 优点 | 缺点 |
|------|------|
| **功能最全** (15 个工具) | **代码量大**, 维护复杂 |
| **WWDC 数据离线内置** (35MB) | npm 包体积大 (因内置 WWDC 数据) |
| 智能 UserAgent 池 | 纯内存缓存, 重启清空 |
| TTL 分级缓存策略 | 代码中大量 `any` 类型, 类型安全较差 |
| 无状态工具, 使用简单 | 部分 URL 硬编码为 SwiftUI 路径 |
| 多语言文档支持 | 不支持 HIG / 外部 DocC |

### sosumi.ai

| 优点 | 缺点 |
|------|------|
| **渲染质量最高** (完整 Markdown) | **不支持 Technology 浏览/符号搜索** |
| **多形态** (HTTP API + MCP + CLI) | 无应用层缓存, 依赖 CDN |
| 支持 HIG + 外部 DocC | MCP 工具数最少 (4 个) |
| 完善的合规处理 (robots.txt / 限速 / 声明) | 需要网络连接 |
| **Cloudflare Worker 部署**, 边缘计算 | 自托管需要 wrangler/CF 生态 |
| 代码质量最高 (Biome, vitest, TypeScript 严格) | |
| 面包屑导航 + YAML front matter | |

---

## 七、适用场景推荐

| 场景 | 推荐 | 理由 |
|------|------|------|
| **纯 MCP + 最全功能** | apple-docs-mcp | 15 个工具, 覆盖搜索/文档/WWDC/示例代码 |
| **高质量文档阅读 + HIG** | sosumi.ai | 渲染质量最佳, 唯一支持 HIG |
| **离线/弱网环境** | apple-doc-mcp | 文件缓存 + WWDC 内置数据 (apple-docs-mcp) |
| **非 MCP 集成** (HTTP API / CLI) | sosumi.ai | 唯一提供 HTTP API 和 CLI |
| **生产环境部署** | sosumi.ai | 合规处理最完善, 代码质量最高 |
| **快速原型/个人使用** | apple-doc-mcp | 最轻量, 安装即用 |

---

## 八、数据内容全面性对比

| 内容维度 | apple-doc-mcp | apple-docs-mcp | sosumi.ai |
| :--- | :---: | :---: | :---: |
| **API 文档深度** | 基础 (标题/摘要) | 丰富 (声明/参数/多段落) | **极其完整** (接近官方 Web 体验) |
| **代码声明 (Swift/OC)** | No | Yes | Yes (高亮支持) |
| **搜索范围** | 仅所选 Framework 内 | **全站搜索** (HTML 爬取) | 全站搜索 (JSON 接口) |
| **WWDC 视频内容** | No | **全量离线 (2012-2025)** | **在线转录抓取** |
| **HIG (人机设计规范)** | No | No | **Yes - 全量覆盖** |
| **第三方库文档** | No | No | **Yes - 支持任意 Swift-DocC URL** |
| **示例代码 (Sample Code)** | No | **Yes - 独立工具检索** | No |
| **平台生命周期分析** | No | **Yes - 深度分析 (Beta/Deprecated)** | Yes - 页面内包含 |
| **API 关系网** | No | **Yes - 深度拓扑 (Related/Similar/See Also)** | Yes - 线性 (Topic Sections) |
| **文档更新记录** | No | **Yes - 包含 Release Notes** | No |

---

## 九、社区健康度与维护风险

| 指标 | apple-doc-mcp | apple-docs-mcp | sosumi.ai |
|------|:---:|:---:|:---:|
| **GitHub Stars** | 580 | **1,100+** | 332 |
| **Forks** | 31 | - | 18 |
| **核心维护者** | 1 人 (MightyDillah) | 1 人 (kimsungwhee) | NSHipster 团队 |
| **Bus Factor** | 1 | 1 | 1-2 (NSHipster 品牌背书) |
| **测试覆盖** | 无测试 | Jest 测试套件 | Vitest 测试套件 |
| **CI/CD** | 无 | GitHub Actions | GitHub Actions + OIDC 发布 |
| **代码规范** | XO linter | ESLint | **Biome** (格式化+lint+import) |
| **npm 发布频率** | 不规律 | 较频繁 (v1.0.26) | 稳定 (v1.0.0) |

> [!WARNING]
> 三个项目的 Bus Factor 都为 1, 这意味着如果核心维护者停止维护, 项目可能会迅速停滞。`sosumi.ai` 因为背靠 NSHipster 品牌 (知名 Swift 社区资源), 风险相对较低。

---

## 十、Token 消耗效率 (AI Agent 关键指标)

对 AI Agent 来说, 每次工具调用的返回内容都会占用 **context window**。返回内容太多反而有害。

| 维度 | apple-doc-mcp | apple-docs-mcp | sosumi.ai |
|------|:---:|:---:|:---:|
| **单次返回量** | 较少 (数百 token) | 中等 (数百~数千) | 较多 (数千 token) |
| **完成任务的调用次数** | 3-4 次 (状态串联) | 1-2 次 | 1 次 |
| **总 token 消耗** | 中等 | 中等 | 中等 |
| **信息密度** (有效信息/总 token) | 低 (信息量少) | **最高** | 中等 (含冗余元数据) |

**分析:**
- `sosumi.ai` 返回完整 Markdown 含 front matter, 面包屑, footer 等**非核心内容**, 会消耗额外 token
- `apple-docs-mcp` 每次返回信息密度最高, 因为它的输出是**结构化的精简内容**
- `apple-doc-mcp` 单次返回少, 但需要**多次串联调用**来完成一个查询任务, 总体效率不佳

---

## 十一、法律合规与风险评估

| 维度 | apple-doc-mcp | apple-docs-mcp | sosumi.ai |
|------|:---:|:---:|:---:|
| **合规声明** | 无 | 无 (仅 Disclaimer) | **完整法律条款** |
| **robots.txt 遵守** | 无 | 无 | Yes |
| **限速机制** | 无 | 无 | 明确声明 |
| **opt-out 机制** | 无 | 无 | `X-Robots-Tag: noai` |
| **数据存储声明** | 无 | 内置 WWDC 数据 | "仅短暂缓存, 不永久存档" |
| **联系方式** | 无 | 无 | info@sosumi.ai |

> [!CAUTION]
> **核心风险**: 三者都依赖 Apple 未公开的 `developer.apple.com/tutorials/data` JSON API。这不是官方公开 API, Apple 随时可能修改接口、增加认证或直接封禁。`apple-docs-mcp` 将 35MB WWDC 数据打包进 npm 包, 可能涉及 Apple 内容再分发的版权风险。

---

## 十二、错误处理与韧性

| 维度 | apple-doc-mcp | apple-docs-mcp | sosumi.ai |
|------|:---:|:---:|:---:|
| **API 403/429 处理** | 直接抛错 | 有 UserAgent 轮换重试 | 有 UserAgent 随机 |
| **网络超时** | 15s timeout | 有 timeout | 有 timeout |
| **缓存损坏恢复** | 基础 (ENOENT 检查) | 基础 | 无应用层缓存 |
| **优雅降级** | 缺乏 | 有 fallback 逻辑 | 有 NotFoundError 分类 |
| **日志/调试** | console.error | 分级 logger | console.error/warn |
| **递归保护** | 无 | maxDepth=2 | 50 层 content / 20 层 inline |

---

## 十三、开发者集成体验

| 维度 | apple-doc-mcp | apple-docs-mcp | sosumi.ai |
|------|:---:|:---:|:---:|
| **安装步骤** | 1 步 (`npx`) | 1 步 (`npx`) | 2 步 (需 `mcp-remote` 代理) |
| **首次可用时间** | <30s | ~1min (下载 35MB) | <30s |
| **配置复杂度** | 零配置 | 可选 env 变量 (UserAgent 策略等) | 零配置 |
| **客户端兼容文档** | Claude + Codex | **7 种客户端详细指南** | 含客户端专页 |
| **错误信息可读性** | 基础 | 含 emoji + 分步引导 | 基础 |
| **本地开发体验** | `pnpm build` | `pnpm dev` (watch mode) | `npm run dev` (wrangler) |

---

## 十四、依赖健康度

| 依赖项 | 所属项目 | 风险评估 |
|--------|----------|----------|
| `axios` | apple-doc-mcp | 极成熟, 维护活跃 |
| `@modelcontextprotocol/sdk` | 三者共有 | 官方维护 |
| `cheerio` | apple-docs-mcp, sosumi.ai | 成熟, HTML 解析标准库 |
| `zod` | apple-docs-mcp (v4), sosumi.ai (v3) | 两者使用不同大版本, 可能存在 API 差异 |
| `hono` | sosumi.ai | 活跃, Cloudflare 生态标配 |
| `robots-parser` | sosumi.ai | 小众但稳定 |
| `wrangler` | sosumi.ai (dev) | 仅部署依赖, Cloudflare 官方 |

**npm 包安装体积** (估算):

| 项目 | 包体积 | 主要原因 |
|------|--------|----------|
| apple-doc-mcp | ~2MB | 轻量, 仅 dist + axios |
| apple-docs-mcp | **~40MB+** | 内置 35MB WWDC JSON 数据 |
| sosumi.ai | ~5MB | 中等, hono + cheerio |

> [!NOTE]
> `apple-docs-mcp` 的 40MB+ 包体积对 `npx` 首次启动速度有显著影响, 在弱网环境下可能需要 1 分钟以上才能首次运行。

---

## 十五、AI Agent Skill: 选择与集成建议

### 1. 谁是不可或缺的?

某些特定能力被特定项目"垄断", 如果你的 Agent 需要这些能力, 则该工具不可或缺:

- **UI/UX 设计建议**: **sosumi.ai** 不可或缺。唯一支持 Apple HIG (人机界面指南)。
- **开源 Swift 库文档**: **sosumi.ai** 不可或缺。唯一支持渲染任意外部 Swift-DocC 站点。
- **深度技术溯源 (WWDC)**: **apple-docs-mcp** 不可或缺。内置 35MB 离线 WWDC 数据库。

### 2. 全场景通用解?

| 维度 | apple-docs-mcp (通用核心) | sosumi.ai (关键补丁) |
| :--- | :--- | :--- |
| **角色** | Agent 的"知识百科" | Agent 的"美学顾问"和"外援" |
| **覆盖** | 开发过程 90% 的 API、代码示例和 WWDC | 剩下 10%: HIG 设计规范 + 第三方库文档 |
| **集成方案** | **首选集成** | **增强插件** |

### 3. 最终集成策略

- **标准开发 Agent**: 集成 `apple-docs-mcp`
- **全栈/高级设计 Agent**: `apple-docs-mcp` + `sosumi.ai` 组合

> [!TIP]
> **apple-doc-mcp** 更适合作为开源二次开发的基石 (代码最清晰), 而非直接集成为生产级 Agent Skill。
