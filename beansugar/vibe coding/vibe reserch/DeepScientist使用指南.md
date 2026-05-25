# DeepScientist 使用指南

> **创建时间**: 2026-05-25
> **项目位置**: `D:\project\DeepScientist`
> **状态**: ✅ 已部署，daemon运行中

---

## 一、DeepScientist 是什么？

**DeepScientist** 是一个**本地优先的自治AI科研工作室**。与Sibyl的一次性全自动化不同，它更像一个**长期运行的工作区**：

| 特性 | Sibyl | DeepScientist |
|------|-------|----------------|
| 设计理念 | 19阶段全自动化流程 | 本地科研工作区，持续迭代 |
| 运行方式 | 一次性完成 | 长期运行，随时可中断 |
| 人工干预 | 较少 | 随时可接管 |
| 文件管理 | 工作区目录 | 独立 git 仓库（每个项目一个） |
| 历史记录 | 较少 | 完整保留所有实验和结果 |
| 适合场景 | 快速生成论文初稿 | 长期深入研究、复现论文 |

### 核心概念：Quest

DeepScientist 中每个研究项目叫一个 **Quest**。每个 Quest 有独立的 git 仓库，所有实验代码、结果、笔记都保留在本地。

---

## 二、如何启动 DeepScientist

### 当前配置

```
Runner: OpenCode v1.14.41
模型: deepseek/deepseek-chat (via 智谱/zai API)
Web UI: http://127.0.0.1:20999
默认语言: 中文 (zh-CN)
```

### 启动步骤

**1. 启动 daemon（后台服务）**

```powershell
cd D:\project\DeepScientist
node .\bin\ds.js daemon
```

> daemon 是后台进程，启动后保持运行，Quest 会在里面持续工作。

**2. 打开浏览器访问**

```
http://127.0.0.1:20999
```

**3. 如果要停止**

```powershell
node .\bin\ds.js --stop
```

**4. 查看状态**

```powershell
node .\bin\ds.js --status
node .\bin\ds.js doctor --runner opencode
```

### 一键启动脚本

可以把下面内容保存为 `start_deepscientist.bat`：

```bat
@echo off
cd /d D:\project\DeepScientist
echo 启动 DeepScientist daemon...
node .\bin\ds.js daemon
echo.
echo Web UI: http://127.0.0.1:20999
echo 按 Ctrl+C 停止
pause
```

---

## 三、Web UI 界面概览

打开 `http://127.0.0.1:20999` 后，首页有三个主要入口，对应三种不同状态：

### 三大入口

| 入口 | 对应状态 | 功能 |
|------|----------|------|
| **Start Research** | "我已经知道要研究什么" | 直接打开启动输入框，把目标、材料、限制、期望产物写进去，SetupAgent 会先做启动规划 |
| **BenchStore** | "我还没确定任务" | 像 App Store 一样浏览 benchmark，已安装的直接 Start，未安装的先 GET / Download |
| **Settings** | "我先调整系统配置" | 处理系统层问题：runner（Codex/Claude/Kimi/OpenCode）、connector、DeepXiv、代理、诊断 |

> **一句话记住**：Start Research 是自定义任务入口，BenchStore 是开放 benchmark 入口，Settings 是系统控制面。

### 进入项目后的工作区

| 区域 | 功能 |
|------|------|
| **Open Project** | 打开已有 Quest，继续之前的研究 |
| **Canvas** | 项目可视化面板（研究图、阶段进度） |
| **Studio** | 实时查看 AI 在工作区里做什么 |
| **Files** | 浏览项目文件（代码、数据、图表、论文） |
| **Memory** | 查看全局和项目级别的记忆卡片 |
| **Diff** | 对比文件变更，回看修改历史 |

---

## 四、BenchStore：Benchmark 商店

BenchStore 是 DeepScientist 内置的 benchmark 商店，像 App Store 一样浏览、筛选和安装研究任务。**目标是先回答：当前这台机器、当前兴趣条件下，哪个 benchmark 最值得启动？**

### 4.1 商店结构

| 侧栏分类 | 用途 |
|----------|------|
| **Recommended** | 优先展示当前机器更适合的任务 |
| **All** | 完整目录，适合审计和逐项比较 |
| **AISB** | AI Scientist Bench 任务集中查看 |
| **LLM / CV / ML / Systems** | 按技术方向筛选 |
| **Installed** | 只看已安装或已有 quest 关联的任务 |
| **Bench Library** | 回到本地任务库视角 |

顶部搜索栏可在当前目录中快速定位任务。主视觉卡展示推荐任务，"查看全部"进入完整目录。**已安装任务显示"开始"，未安装显示"获取"。**

### 4.2 推荐浏览顺序

```
Recommended → 快速获得可运行候选
      ↓
  有兴趣？→ 打开详情页确认
      ↓
  All    → 想系统审计时看完整列表
      ↓
  LLM/CV/ML/Systems → 目标明确时按方向筛选
      ↓
Installed → 回看已安装任务，直接启动
```

### 4.3 阅读详情页

总览页适合比较，**详情页负责决策**。打开一个 benchmark 详情页后，按顺序检查：

| 检查项 | 要确认的内容 |
|--------|-------------|
| **兼容性和推荐分** | 当前机器是否满足最低/推荐资源 |
| **任务目标** | 要求复现、改进、评测还是写作 |
| **论文和来源** | paper、venue、repo、下载地址、数据源 |
| **安装状态** | 本地路径是否存在，是否需要获取或重装 |
| **风险和约束** | 是否需要凭证、外部数据、长时间运行或高成本 |

读详情页的最终目标：**我为什么选这个 benchmark？它需要什么资源？启动后 DeepScientist 应该产出什么？**

### 4.4 动作区

| 按钮 | 状态 | 行为 |
|------|------|------|
| **开始 / Start** | 已安装 | 读取 setup packet，把 benchmark 目标、本地路径、论文和运行约束带入 Start Research 表单 |
| **获取 / GET** | 未安装 | 下载、校验并准备本地资源 |
| **进度条** | 下载中 | 显示当前状态 |

> 规则很简单：已就绪就 Start，没安装就 GET，安装异常时重新获取或检查本地路径。

---

## 五、Start Research：启动表单详解

> 从 Start Research 进入时，默认先看到大输入框。把目标、材料、限制、期望产物写进去，SetupAgent 会先做启动规划。

这里**不是普通聊天入口**，而是把研究想法推进成**本地可审计、可复现 Quest** 的起点。

### 5.1 主线流程

```
选择任务 → 启动规划 → 执行研究 → 审计结果 → 系统监管
```

| 阶段 | 说明 |
|------|------|
| **① 选择任务** | 自己用自然语言描述研究目标，或从 BenchStore 选一个 benchmark |
| **② 启动规划** | SetupAgent 自动整理目标、材料、限制和启动合同（startup contract） |
| **③ 执行研究** | 进入 Quest 工作区，持续运行 scout → idea → experiment → write 等阶段 |
| **④ 审计结果** | 用 Canvas、Files、Diff、Memory 和 Copilot 回看证据链 |
| **⑤ 系统监管** | 需要时到 Settings / Admin 查看运行状态、runner、connector 和诊断 |

### 5.2 核心原则：不要只写"研究某个方向"

❌ **差的请求**：
> 研究一下图像识别
> 研究深度学习

✅ **好的请求**：

> 复现论文 X 的 baseline，在数据集 Y 上与官方指标对齐；若复现可信，再尝试一个小改进，并输出对比表和失败原因。

> 基于 Swin Transformer 的植物病害识别，在 PlantVillage 数据集 39 类分类任务上，尝试 CutMix + Mixup 数据增强策略，目标相对 baseline 提升 ≥ 3% 准确率。使用 GTX 1650 4GB，单次实验 ≤ 30 分钟，生成实验对比图表和论文初稿。

**好的启动请求 = 背景 + 目标 + 成功标准 + 限制 + 产物**：

| 要素 | 要写什么 |
|------|---------|
| **背景** | 我要研究哪个问题、benchmark 或论文 |
| **目标** | 需要复现、改进、评测、写作，还是先审计可行性 |
| **成功标准** | 什么证据说明它完成了 |
| **限制** | GPU、时间、网络、数据隐私、外部 API、不能改哪些东西 |
| **产物** | 实验记录、对比表、图、报告、论文草稿、issue 或 PR |

### 5.3 选择启动模式

点击 "Start Research" 后，先选择模式：

- **Copilot Mode（推荐新手）**：安静启动，AI 等你发指令，做完一件事就停下来等你发下一个指令。适合先熟悉流程、需要精细控制每一步的情况。
- **Autonomous Mode**：标准 DeepScientist 模式，AI 自主推进研究，自动连续运行多个阶段。适合目标明确、想放手的场景。

> 建议第一次用 **Copilot Mode** 熟悉流程，后续成熟项目切换 Autonomous。

### 5.4 填写项目信息

**Project title**（项目名称）

一个好的标题应该让你在几天后还能一眼认出来：主题 + 目标，尽量短但包含关键 benchmark 或方法名。方便在 quest 列表、文件树和 Admin 表里搜索。示例：`TreeHFD benchmark 复现与改进`、`LLM 长上下文评测 baseline 审计`。第一次练习时通常不需要手动改 Project ID。

**Primary research request**（研究请求 — 最重要！）

它决定 agent 第一轮会如何拆任务。建议使用这个结构：

```
背景：我要研究哪个问题、benchmark 或论文
目标：需要复现、改进、评测、写作，还是先审计可行性
成功标准：什么证据说明它完成了
限制：GPU、时间、网络、数据隐私、外部 API、不能改哪些东西
产物：实验记录、对比表、图、报告、论文草稿、issue 或 PR
```

**Baseline links & Reference papers**（强锚点）

最有价值的参考通常是：
- 已确认的 baseline 仓库或本地路径
- 论文 URL、arXiv、DOI 或 PDF
- benchmark 页面、leaderboard、数据说明
- 已知可运行的参考实现
- 之前 quest 的结论或 Memory 记录

如果任务来自 BenchStore，这里通常会自动带入 paper、下载地址和本地安装路径。你仍然可以补充自己的材料。

**Connector**（可选投递目标）

Connector 不是必填项。留空时，所有进展保留在 Web 工作区。选择 connector 后，系统可把关键消息投递到外部会话（微信/QQ/Telegram 等），例如：里程碑更新、长任务完成/失败提醒、等待决策的中断、需要人工补充凭证的请求。

**DeepXiv**（文献发现）

- 需要系统性文献检索 → 配置 DeepXiv
- 只做本地代码复现或 benchmark 启动 → 可暂时跳过
- 从 BenchStore 进入且已有 paper → 先使用自动带入的 paper

它会影响 scout / idea / write 阶段可以依赖的论文来源。

**启动合同（Startup Contract）**

启动合同决定第一轮研究如何开始：

| 字段 | 含义 | 建议 |
|------|------|------|
| **Launch mode** | 使用标准研究图还是自定义路线 | Standard |
| **Research intensity** | 第一轮推多深 | Balanced（先验 baseline，再测一个方向） |
| **Decision policy** | 什么时候必须停下来等你 | Autonomous（自动推进）或 Manual（每步确认） |
| **Runtime constraints** | 硬边界：时间、GPU、网络、数据和安全 | 写清楚，不要用模糊词 |
| **Research paper** | 是否产出论文/报告 | On（自动生成论文级产出） |

> 稳妥做法：第一次保持 Standard + Balanced，把硬限制写清楚。不要用启动合同掩盖一个模糊目标。

### 5.5 SetupAgent（启动规划助手）

右侧的 SetupAgent 会根据左侧表单、BenchStore setup packet、本机限制和你拖入的材料，帮助补齐更安全的启动上下文。它适合处理：

- 目标是否太宽，需要先收窄
- 当前机器是否适合这个任务
- baseline、paper、数据和运行限制是否足够明确
- 应该全自动启动，还是先进入协作模式

> 点击上方的 **Preview** 可切换到启动预览，自己检查最终 prompt。

### 5.6 最终预览 & 创建项目

创建前至少检查四件事：
1. 任务是否与你真正想做的一致
2. benchmark、本地路径、paper、baseline 是否正确
3. 运行限制是否足够明确，不会让 agent 过度使用资源
4. 预期产物是否具体（表格、图、报告、论文草稿或 PR）

> 如果预览读起来不对，先回到左侧修改字段，或切回 SetupAgent 让它帮你重写。

准备好后点击 **Create project**。这会创建 quest 工作区，把启动表单编译成第一轮研究上下文。

### 5.6 Quest 创建示例

**从零开始的研究**：
```
背景：研究AI Agent的安全防护，重点探索Prompt Injection防御方法
目标：基于OpenClaw框架设计轻量级防护层，能在本地Windows环境运行
成功标准：TPR > 90%, FPR < 5%，成本降低50%以上
限制：GTX 1650 4GB，本地部署
产物：实验报告、对比表、论文初稿
```

**基于论文复现**：
```
背景：复现论文 X 的 baseline
目标：在数据集 Y 上与官方指标对齐，若可信再尝试小改进
成功标准：指标对齐 ± 2% 以内
限制：与原论文相同的实验设置和评价指标
产物：对比表、失败原因分析
```

---

## 六、项目创建后的工作区

创建项目后，你会在工作区里看到以下核心面板：

### 6.1 顶部栏

顶部栏帮确认三件事：当前在哪个 quest、教程是否在运行（暂停/跳过/重播）、如何回到首页或切换视图。长期项目里离开一段时间再回来，先看顶部栏确认当前位置。

### 6.2 Explorer / Files（文件浏览器）

不只拿来浏览文件名，而是进入具体 artifact 的入口。点击文件项，中间区域会从总览切换成文件内容。markdown 文件可以作为 quest 内部的**私有笔记本**——本地优先、随时可编辑。

> 在真实使用中，用户通常在这里判断工作区里是否已有足够可信的持久内容。

### 6.3 Canvas（研究地图）

**不是装饰图**，而是把阶段、分支和证据关系可视化：

| 元素 | 内容 |
|------|------|
| baseline / 初始状态 | 起点 |
| scout / idea / experiment / write 等阶段节点 | 当前进度 |
| 被推进、放弃或需复查的分支 | 路线选择 |
| 与节点关联的文件、diff、摘要和产物 | 证据链 |

> 读 Canvas 的目的不是看"最后成功了吗"，而是理解项目**为什么走到现在**：哪条路线被验证、哪条路线失败、下一步该检查哪里。

### 6.4 Details（状态摘要）

回答一个问题：**这个项目现在到底是什么状态？** 当你想快速且较高置信度地理解进展时，就看这一页。重新回到正在推进的 quest 时，通常先看这里。

### 6.5 Memory（持久记忆）

Memory 保存**跨轮次仍然重要的内容**，不是聊天记录备份：

| 类型 | 示例 |
|------|------|
| **决策** | 为什么选择方案 A 而不是 B |
| **知识** | 有效方法、失败路线和原因 |
| **边界** | 重要的 claim、证据和适用条件 |
| **经验** | 未来阶段必须复用的教训 |

> 如果项目运行了很多轮，Memory 往往比聊天记录更值得先看。它告诉你哪些东西已被确认，哪些坑不该再踩。

### 6.6 Studio vs Chat（两种协作模式）

| 面板 | 用途 | 何时用 |
|------|------|--------|
| **Studio** | 执行轨迹、工具调用、输出结果、里程碑 artifact | 需要搞清楚到底发生了什么时 |
| **Chat / Copilot** | 自然语言协作入口 | 已经知道要告诉系统什么时 |

> 正常使用中来回切换是很正常的。项目复杂时先看 Studio，搞清楚后切回 Chat。

### 6.7 Copilot（协作接管）

Copilot 适合在项目运行中处理三类事情：
- **追问状态**：为什么这么做、证据在哪里、下一步是什么
- **改变路线**：要求更保守、更深入、先写报告、先跑测试或停止某条分支
- **收尾审计**：整理产物、列风险、写 issue、准备 PR 或生成总结

> 关键点：Copilot 不是临时聊天，它会结合当前 quest、文件、阶段和运行状态回答。

---

## 七、系统监管

### 7.1 Admin Summary（运维总览）

回答三件事：现在有什么在运行、哪里看起来不健康、当前运行时使用怎样的硬件边界。日常新手使用中不需要一直来这页。

### 7.2 Quest Supervision（任务监管）

统一查看多个 quest 的运维表。需要时来这里：在长列表里找到某个 quest、看哪个 quest 在等待/卡住/需要处理、判断当前最该先关注哪一个。

### 7.3 Admin Copilot（管理助手）

自动带上当前设置页上下文的排查助手。可以做三类事：
- 让它自己检查当前页面、日志、运行状态
- 让它帮你把问题整理成 issue 或修复清单
- 需要时继续推进修复、验证和收尾

---

## 八、管理命令速查

```powershell
# 在 D:\project\DeepScientist 目录下执行

# 启动
node .\bin\ds.js daemon

# 指定端口启动
node .\bin\ds.js daemon --port 21000

# 当前目录启动（home 放在当前目录下）
node .\bin\ds.js daemon --here

# 查看状态
node .\bin\ds.js --status

# 运行诊断
node .\bin\ds.js doctor --runner opencode

# 停止
node .\bin\ds.js --stop

# 安装 LaTeX（可选，用于生成PDF）
node .\bin\ds.js latex install-runtime
```

---

## 九、切换模型 / Runner

### 当前使用：OpenCode + DeepSeek

默认配置在 `C:\Users\24796\DeepScientist\config\` 下：

**config.yaml**：
```yaml
default_runner: opencode
```

**runners.yaml**：
```yaml
opencode:
  enabled: true
  model: deepseek/deepseek-chat
  # 想用推理模型可以改为:
  # model: deepseek/deepseek-reasoner
```

### 切换到其他模型

如果 Anthropic key 更新后想用 Claude：
```yaml
opencode:
  model: anthropic/claude-sonnet-4-5
```

### 通过 Web UI 切换

进入 Settings → Models 页面，可以直接可视化切换 runner 和模型。

---

## 十、常用技巧

### 8.1 研究约束怎么写

给 DeepScientist 明确的边界很重要：

```
Runtime constraints:
- 使用 GPU: GTX 1650 4GB（显存受限）
- 模型规模需适配 4GB 显存
- 数据集不超过 10GB
- 单次实验不超过 30 分钟
- Python 版本: 3.12
- 记录失败的实验供分析
```

### 8.2 Goals 怎么写

用具体可衡量的目标：

```
Goals:
1. 复现 baseline 并验证指标一致
2. 尝试至少 2 种数据增强方法
3. 准确率相对 baseline 提升 ≥ 3%
4. 生成完整实验报告和分析
```

### 10.3 中途接管

如果 AI 方向跑偏了，直接在 Copilot 模式下发指令纠正。如果是 Autonomous 模式，可以在 Settings 中切换到 Copilot 再接管。

### 10.4 多项目并行

在 `~/DeepScientist/config/config.yaml` 中：
```yaml
daemon:
  max_concurrent_quests: 1  # 改为 2 或更多可并行
```

> 注意：多项目并行会更耗显存和 API 调用。

### 10.5 成本控制

当前使用智谱/zai API + DeepSeek，DeepSeek 价格很低：
- deepseek-chat: 约 ¥1/百万token 输入，¥2/百万token 输出
- deepseek-reasoner: 略贵

建议：
- 日常用 `deepseek-chat`
- 关键分析/论文写作时切到 `deepseek-reasoner`
- 如果 zai API Anthropic 密钥更新后可用 Claude，质量更好但成本更高

---

## 十一、与 Sibyl 配合使用

推荐策略：

```
Sibyl（1-2天）              DeepScientist（1-4周）
快速生成论文初稿     →      深入实验验证和优化
19阶段全自动         →      持续迭代，人工可接管
快速产出             →      精雕细琢
```

**组合流程**：
1. Sibyl 快速生成论文初稿和实验方向
2. 把论文中的实验结果作为 DeepScientist 的 baseline
3. DeepScientist 深入验证、扩展实验
4. 完善论文，达到投稿标准

---

## 十二、故障排查

### daemon 启动失败
```powershell
# 先运行诊断
node .\bin\ds.js doctor --runner opencode

# 检查端口是否被占用
netstat -ano | findstr 20999
```

### OpenCode 不可用
```powershell
# 验证 opencode
opencode run --format json --pure "Reply with HELLO" --model deepseek/deepseek-chat

# 检查认证
opencode auth list
```

### Web UI 打不开
检查 daemon 是否在运行：
```powershell
node .\bin\ds.js --status
```

### 内存/显存不足
在 Runtime constraints 中明确限制，或在 runners.yaml 中设置更小的并发数。

---

## 十三、文件位置速查

| 内容 | 路径 |
|------|------|
| DeepScientist 代码 | `D:\project\DeepScientist` |
| 配置目录 | `C:\Users\24796\DeepScientist\config\` |
| runner 配置 | `C:\Users\24796\DeepScientist\config\runners.yaml` |
| 主配置 | `C:\Users\24796\DeepScientist\config\config.yaml` |
| Quest 存储 | `C:\Users\24796\DeepScientist\quests\` |
| 日志 | `C:\Users\24796\DeepScientist\logs\` |
| 全局记忆 | `C:\Users\24796\DeepScientist\memory\` |
| OpenCode 配置 | `C:\Users\24796\.config\opencode\` |
| OpenCode 凭证 | `C:\Users\24796\.local\share\opencode\auth.json` |

---

**当前 Vibe**: DeepScientist 已就绪，准备第一个 Quest！

**下一步**: 打开 `http://127.0.0.1:20999`，创建你的第一个研究项目。
