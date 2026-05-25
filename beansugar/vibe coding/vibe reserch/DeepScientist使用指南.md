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

## 四、研究启动页：从一个想法到一个 Quest

欢迎来到 DeepScientist 的研究启动页。

这里**不是普通聊天入口**，而是把研究想法推进成**本地可审计、可复现 Quest** 的起点。

### 4.1 DeepScientist 主线流程

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

### 4.2 核心原则：不要只写"研究某个方向"

❌ **差的请求**：
> 研究一下图像识别

✅ **好的请求**：
> 基于 Swin Transformer 的植物病害识别，在 PlantVillage 数据集 39 类分类任务上，尝试 CutMix + Mixup 数据增强策略，目标相对 baseline 提升 ≥ 3% 准确率。使用 GTX 1650 4GB，单次实验 ≤ 30 分钟，生成实验对比图表和论文初稿。

**好的启动请求 = 目标 + 证据 + 约束 + 预期产物**，必须包含：

| 要素 | 说明 | 示例 |
|------|------|------|
| **研究问题或 benchmark** | 要解决什么问题 | 植物病害细粒度分类 |
| **已有论文、代码、数据或 baseline** | 从哪开始 | arXiv 2312.xxxxx + GitHub repo 链接 |
| **机器和时间限制** | 现实约束 | GTX 1650 4GB，24小时内 |
| **成功标准** | 什么算完成 | 复现 baseline、改进 ≥ 3%、图表、报告或论文草稿 |

### 4.3 选择启动模式

点击 "Start Research" 后，先选择模式：

- **Copilot Mode（推荐新手）**：安静启动，AI 等你发指令，做完一件事就停下来等你发下一个指令。适合先熟悉流程、需要精细控制每一步的情况。
- **Autonomous Mode**：标准 DeepScientist 模式，AI 自主推进研究，自动连续运行多个阶段。适合目标明确、想放手的场景。

> 建议第一次用 **Copilot Mode** 熟悉流程，后续成熟项目切换 Autonomous。

### 4.4 填写项目信息

| 字段 | 说明 | 示例 |
|------|------|------|
| Project title | 项目名称 | 植物病害识别模型优化 |
| Primary research request | 研究核心内容描述 | 基于Swin Transformer的植物病害图像识别，探索数据增强和模型优化策略 |
| Baseline links | 参考仓库/GitHub链接 | https://github.com/xxx/baseline |
| Reference papers | 参考论文/arXiv链接 | https://arxiv.org/abs/xxx |
| Runtime constraints | 运行约束条件 | 使用GTX 1650 4GB，轻量级实验，Python 3.12 |
| Goals | 具体目标 | 1.复现baseline 2.实验数据增强 3.提升准确率 |
| Research paper | 是否生成论文 | On（自动生成） |
| Research intensity | 研究强度 | Balanced（平衡），Intensive（深度），Quick scan（快速） |
| Decision mode | 决策模式 | Autonomous（自动推进），Manual（每步人工确认） |
| Language | 语言 | 中文或 English |

### 4.5 Quest 创建示例

**从零开始的研究（自然语言描述）**：

```
Primary research request:
研究AI Agent的安全防护机制，重点探索Prompt Injection的防御方法。
基于OpenClaw框架，设计一个轻量级的防护层，能在本地Windows环境运行。
目标：TPR > 90%, FPR < 5%，成本降低50%以上。
```

**基于论文复现**：

```
Baseline links:
https://github.com/xxx/repo

Reference papers:
https://arxiv.org/abs/xxxx

Primary research request:
复现上述论文的baseline，然后尝试改进模型结构。
保持原论文的实验设置和评价指标不变。
```

---

## 五、使用流程详解

### 5.1 项目创建后的事

创建 Quest 后，DeepScientist 会自动：

1. 初始化 git 仓库（在 `~/DeepScientist/quests/` 下）
2. 加载深度科研技能（skill bundles）
3. 根据你的输入生成研究计划
4. 根据模式（Copilot/Autonomous）开始工作

### 5.2 在 Copilot Mode 下操作

```
你 → 发指令（如 "先做文献调研"）
AI → 执行，完成后报告结果
你 → 审核，给下一步指令
AI → 继续...
```

### 5.3 在 Autonomous Mode 下操作

```
你 → 填好表单，点击创建
AI → 自主运行，自动进行：文献调研 → 实验设计 → 代码编写 → 运行实验 → 分析结果 → 写论文
你 → 随时查看进度，需要时可以接管
```

### 5.4 查看进度

- **Studio 面板**：实时查看 AI 在执行什么操作
- **Canvas 面板**：查看研究流程图、阶段进度
- **文件浏览器**：查看生成的代码、数据、图表
- **Git 历史**：每次关键步骤自动 commit，可回看所有变更

---

## 六、管理命令速查

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

## 七、切换模型 / Runner

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

## 八、常用技巧

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

### 8.3 中途接管

如果 AI 方向跑偏了，直接在 Copilot 模式下发指令纠正。如果是 Autonomous 模式，可以在 Settings 中切换到 Copilot 再接管。

### 8.4 多项目并行

在 `~/DeepScientist/config/config.yaml` 中：
```yaml
daemon:
  max_concurrent_quests: 1  # 改为 2 或更多可并行
```

> 注意：多项目并行会更耗显存和 API 调用。

### 8.5 成本控制

当前使用智谱/zai API + DeepSeek，DeepSeek 价格很低：
- deepseek-chat: 约 ¥1/百万token 输入，¥2/百万token 输出
- deepseek-reasoner: 略贵

建议：
- 日常用 `deepseek-chat`
- 关键分析/论文写作时切到 `deepseek-reasoner`
- 如果 zai API Anthropic 密钥更新后可用 Claude，质量更好但成本更高

---

## 九、与 Sibyl 配合使用

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

## 十、故障排查

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

## 十一、文件位置速查

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
