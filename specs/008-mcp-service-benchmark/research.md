# Research: 项目级 MCP 接入与四路基准评测

## 1. 冷启动与热启动定义

- **Decision**: 将冷启动定义为 `fresh process + fresh project cache + fresh session state`；将热启动定义为保留同一轮任务中的项目级缓存、连接复用和会话上下文。远端 CDN、DNS 或上游服务缓存不作为强制清空对象。
- **Rationale**: 对 `idocs` CLI、本地 MCP、远端 MCP、外部 HTTP 服务而言，可控且可复测的是本地进程态、项目级缓存目录和会话状态，而不是公网边缘缓存。这样既公平，也能避免把不可控远端缓存误判为本地优化。
- **Alternatives considered**:
  - 强制全链路绝对冷启动：远端缓存不可控，无法稳定复现。
  - 只测热启动：会掩盖首次可用时间和初始化成本。
  - 仅通过固定 sleep 隔离：无法清理进程态、磁盘缓存和连接池。

## 2. 性能与稳定性样本量

- **Decision**: 将 `n>=10` 视为最低门槛。每个 `服务目标 x 共享任务` 至少采集 10 个自动化样本，并至少包含 1 个冷启动样本和 9 个热启动样本；输出 `P50`、`P90`、平均值、标准差、成功率、超时率。仅在样本量足以支撑时输出 `P99`，否则标记为样本不足。
- **Rationale**: 这是 CLI/MCP/外部网络服务的端到端 benchmark，不是微基准。网络抖动、远端负载和初始化开销会放大低样本误差。必须依赖分位数和离散指标来刻画稳定性，而不是只看均值。
- **Alternatives considered**:
  - 所有任务只跑 3 次：统计显著性不足。
  - 只报告平均值：无法揭示尾延迟和波动。
  - 手工删除慢样本：会掩盖真实不稳定性。

## 3. Token 成本边界

- **Decision**: 同时记录 `Avg Token per Call` 与 `Total Token per Task`，并把 `Total Token per Task` 作为最终选型结论的主指标；同时记录完成任务所需的 tool call 次数。
- **Rationale**: AI agent 的真实成本来自“完成一条任务用了多少上下文和多少轮调用”，而不是某一次调用看起来多短。单次返回小但需要多轮串联的目标，会在整任务累计成本上暴露出来。
- **Alternatives considered**:
  - 只看单次调用 token：会奖励多轮工作流。
  - 只看整任务 token：不利于定位成本来自大包返回还是多次调用。
  - 把估算 token 当真实 token：对含导航、front matter、噪声字段的输出误差过大。

## 4. 准确性与完整性客观化

- **Decision**: 使用任务类型相关的 checklist 进行客观评分。准确性拆成 atomic claims 命中率；完整性拆成 required slots 覆盖率；评估者只按证据勾选，不临场定义标准。
- **Rationale**: 当前总分中准确性与完整性占比最高，如果不冻结评分细则，就无法保证跨时间、跨评估者复测的一致性。
- **Alternatives considered**:
  - 完全人工主观评分：复测时漂移过大。
  - 只用整体 1-5 分感受：无法追溯扣分原因。
  - 完全交给 LLM judge：扩展性好，但一致性和可解释性不足。

## 5. 可诊断性量化

- **Decision**: 采用固定四级 rubric：`0=静默失败或超时`、`1=通用错误`、`2=具体错误原因`、`3=具体原因+可执行建议或重试条件`。
- **Rationale**: 可诊断性必须可映射到稳定分值，否则 10% 的权重会退化为“印象分”。
- **Alternatives considered**:
  - 自由文本评价：难以转成稳定分数。
  - 只看错误是否存在：无法区分错误质量。

## 6. 数据格式对比定义

- **Decision**: “数据格式对比”统一定义为 AI agent 的输出可消费性评估，不比较 Markdown/JSON/纯文本表面类型，而按结构可提取性、信息密度、任务适配度、噪声控制、可引用性进行任务内评分。
- **Rationale**: 对 agent 而言，关键不是编码格式，而是能否直接消费、压缩、引用和继续调用。
- **Alternatives considered**:
  - 只按底层格式类别比较：无法反映真实 agent 使用成本。
  - 把格式分并入准确性：会掩盖“内容正确但难消费”的情况。

## 7. 执行顺序与缓存隔离

- **Decision**: 冷启动样本前必须执行环境重置步骤，至少包括目标进程重启、项目级缓存清理和状态隔离说明；共享任务执行顺序采用轮转或随机交错，避免顺序偏置。
- **Rationale**: benchmark 必须防止前序任务给后序目标留下进程态、磁盘缓存或连接复用优势。
- **Alternatives considered**:
  - 固定顺序执行：存在明显的后发优势。
  - 只在整轮开始前清缓存：无法保证每个冷启动样本独立。

## 8. 合同与文档组织方式

- **Decision**: 008 应按“评测系统文档”组织，而不是按代码架构文档组织。合同聚焦统一比较面，包括目标接入合同、评测记录 schema、评分细则，而不是为每个服务单独建代码协议。
- **Rationale**: 008 的核心交付物是项目级接入、统一评测、结果可追溯，而不是新运行时接口。
- **Alternatives considered**:
  - 按每个服务单独写接口合同：重复且不利于统一比较。
  - 只写 spec 不写合同：后续实现易发生字段漂移和评分口径漂移。

## 9. Golden Dataset 预生成

- **Decision**: 在执行任何 benchmark 前，先为至少 12 条任务预生成并冻结 Golden Dataset，包含 Atomic Claims、Required Slots、参考来源和版本锚点；评测阶段只允许按清单勾选 `correct / incorrect / missing / unverifiable`，不允许临场定义事实粒度。
- **Rationale**: 如果 Atomic Claims 是在拿到结果后才由评测者临时抽取，分母会随评测者理解改变，导致准确性与完整性分数失去横向可比性。
- **Alternatives considered**:
  - 边评边抽取 claims：操作灵活，但不可复测。
  - 只冻结参考链接不冻结 claims：仍会留下事实粒度漂移问题。

## 10. Driver 架构

- **Decision**: benchmark 使用受控 Driver，而不是自由对话的实时 Agent。默认采用 `record-replay` 驱动；若需要模型参与路径决策，只允许使用固定提示模板、`temperature=0`、固定输入和可回放上下文的受控 Agent。
- **Rationale**: 如果直接用真实 LLM 做 Driver，同一任务的 tool call 数和路径会随模型波动，污染成本、效率和稳定性测量。
- **Alternatives considered**:
  - 完全自由的实时 LLM：最像真实 Agent，但噪音过大。
  - 纯手写单步脚本：可控，但不能覆盖多轮工具发现和补救路径。

## 11. Tokenizer 统一

- **Decision**: 对所有不可观测 token 统一使用 `cl100k_base` 作为归一化标尺，并在所有记录和报告中声明该 tokenizer 名称与版本。
- **Rationale**: 不同模型词表对同一 Markdown/JSON 的分词差异很大；若不统一 tokenizer，估算 token 结果无法比较。
- **Alternatives considered**:
  - 各目标按各自模型词表估算：失去统一度量基线。
  - 只记录字符数：不能反映真实上下文成本。

## 12. Over-fetching 的评分归属

- **Decision**: 过度召回、无请求噪音和无用大段内容不仅在格式可消费性中扣分，也必须影响主评分中的效率或成本，必要时影响任务完成性判断。
- **Rationale**: 如果某目标返回正确答案但附带大量无关内容，只在格式分扣分会低估它对 Agent 上下文窗口和执行路径的破坏。
- **Alternatives considered**:
  - 仅在格式维度扣分：主总分仍可能虚高。
  - 直接按准确性扣分：会混淆“内容真假”和“内容适配性”。

## 13. 参考真值版本锚定

- **Decision**: 每轮评测都记录 Truth Baseline，包括 Xcode 版本、SDK 版本、官方文档抓取时间或版本锚点；当某目标返回更新或更旧的数据时，先标记为版本偏差，再判断是否影响能力评分。
- **Rationale**: 本地 DocC 缓存、在线官网和第三方服务的数据新鲜度可能不同；若不锁版本，会把数据源更新差异误判成工具能力缺陷。
- **Alternatives considered**:
  - 一律以最新官网为唯一真值：会系统性惩罚离线归档类目标。
  - 完全忽略版本差异：会让结果不可解释。
