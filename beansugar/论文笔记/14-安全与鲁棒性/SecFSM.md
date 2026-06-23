---
title: "SecFSM: Knowledge Graph-Guided LLMs for Generating Secure Verilog Code of Finite State Machine in SoCs"
method_name: "SecFSM"
authors: [Ziteng Hu, Yingjie Xia, Jiachi Chen, Li Kuang, Yao Wan]
year: 2026
venue: IEEE TDSC
tags: [hardware-security, llm-for-eda, fsm, verilog, knowledge-graph, vulnerability-analysis]
zotero_collection: 14-安全与鲁棒性
image_source: online
created: 2026-06-23
doi: 10.1109/TDSC.2026.3679566
---

# 论文笔记：SecFSM

## 元信息

| 项目 | 内容 |
|------|------|
| 机构 | Hangzhou Dianzi University, Zhejiang University, Central South University, HUST |
| 日期 | 2026 |
| 项目主页 | https://github.com/ZitengHu/SecFSM |
| 对比基线 | Base [[LLM]], [[RAG]] |
| 链接 | [IEEE TDSC](https://doi.org/10.1109/TDSC.2026.3679566) / [Code](https://github.com/ZitengHu/SecFSM) |

---

## 一句话总结

> 通过构建 [[FSKG]] 知识图谱指导 [[LLM]] 的两阶段漏洞分析与安全提示，在 FSM Verilog 代码生成中实现 48/52 的安全通过率。

---

## 核心贡献

1. **[[FSKG|FSM Security Knowledge Graph]]**: 三层安全知识图谱（漏洞模式 → 漏洞语义 → 缓解/安全设计模式），为 LLM 提供结构化外部安全知识。
2. **两阶段漏洞分析算法**: Stage I 结构化 FSM 图分析 + Stage II 基于 [[FSKG]] 的知识引导漏洞确认，在代码生成前定位漏洞。
3. **FSM-structure-aware 三阶段安全提示策略**: 将结构化漏洞表示与 [[FSKG]] 对齐的安全知识集成到生成提示中，约束 LLM 输出安全的 FSM 实现。
4. **开源数据集与基准**: 发布 52 个测试用例（涵盖学术/人工/工业案例），含漏洞注入方法，地址 https://github.com/ZitengHu/SecFSM。

---

## 问题背景

### 要解决的问题

[[LLM]] 生成的 [[Verilog]] [[Finite State Machine|FSM]] 代码频繁包含安全漏洞（如 [[CWE-1245]]：缺失 default 语句导致 unreachable states），这对 [[SoC]] 中安全关键的 FSM 设计构成严重威胁。[[CWE-1245]] 漏洞消除可降低约 43% 系统漏洞。

### 现有方法的局限

1. 现有 [[LLM]] 训练数据中 [[Verilog]] 代码占比不足 0.04%，安全关键的 FSM 模式稀疏。
2. [[RAG]] 方案仅提供粗粒度安全知识增强，安全通过率仅 19/52。
3. Base [[LLM]] 直接生成的安全通过率极低（[[GPT-4o]]: 3/52），缺乏 FSM 安全知识。
4. 现有 RTL 生成工作（[[RTLCoder]], [[VerilogCoder]], [[ChipNeMo]]）关注功能正确性，忽视安全约束。

### 本文的动机

FSM 功能正确 ≠ 安全。需通过结构化知识图谱补偿 LLM 缺失的领域安全知识，在生成前进行漏洞分析，并以安全约束形式指导生成过程。

---

## 方法详解

### 整体架构

SecFSM 采用 **知识图谱引导的安全代码生成** 架构，包含三部分：

```
User FSM Requirement R
        │
        ▼
┌───────────────────────────────┐
│  Part 1: Two-stage            │
│  Vulnerability Analysis       │
│  ┌─────────────────────────┐  │
│  │ Stage I: FSM State Info │  │
│  │ Extraction → Build G_ST │  │
│  │ → Graph Analysis        │  │
│  │ (V_S + V_P)             │  │
│  └─────────────────────────┘  │
│  ┌─────────────────────────┐  │
│  │ Stage II: Knowledge-    │  │
│  │ guided Confirmation     │  │
│  │ (V_P → V_P^C) +        │  │
│  │ Knowledge Retrieval K_C │  │
│  └─────────────────────────┘  │
└───────────────────────────────┘
        │
        ▼
┌───────────────────────────────┐
│  Part 2: Knowledge-guided     │
│  Secure FSM Code Generation   │
│  Stage I: Security Prompt P_Se│
│  Stage II: Generation +       │
│  Functional/Security Verify   │
└───────────────────────────────┘
        │
        ▼
    Secure VcF (V_Se)
```

**外部知识**: [[FSKG]] (G_K): 111 nodes, 161 edges, 三层语义

- **输入**: 用户自然语言 FSM 设计需求 $R$（含接口信号、状态定义、转换条件）
- **核心模块**: [[FSKG]] 用于结构化安全知识供给；两阶段漏洞分析用于需求阶段漏洞识别；安全提示模板用于约束生成
- **输出**: 安全且功能正确的 Verilog FSM 代码 $V_{Se}$

### 核心模块

#### 模块1: [[FSKG|FSM Security Knowledge Graph]] 构建

**设计动机**: 利用 [[Knowledge Graph|知识图谱]] 弥补 LLM 训练数据中 FSM 安全知识的稀疏性，提供结构化、可检索的安全指导。

**三层语义架构** (Table I):

| 层级 (Node Type) | 节点数 | 关系类型 |
|------|------|------|
| FSM Vulnerability Level | N=23 | `→ [:stage]`, `→ [:type]` |
| Vulnerability Semantics Level | N=70 | `→ [:Check]`, `→ [:Consequence]`, `→ [:GoodExample]`, `→ [:BadExample]`, `→ [:confirm]`, `→ [:confirm positive]`, `→ [:confirm negative]` |
| Mitigation & Secure Design Pattern Level | N=18 | `→ [:suggestions]`, `→ [:manner]` |

**构建流程**: Data Clean (规范化/去重/过滤) → Data Fusion (人工筛查/实体级语义对齐) → Double-check (两位≥2年经验专家独立验证)

#### 模块2: Two-stage Vulnerability Analysis

**设计动机**: 在代码生成前，从用户需求中提取 FSM 语义并构建安全状态转换图 $G_{ST}$，系统性地识别结构性和潜在漏洞。

**Stage I: Structure-aware FSM Graph Analysis**

1. **FSM State Information Extraction**: 从自然语言需求 $R$ 中提取：
   - Reset state information
   - State information (outputs + protection attributes)
   - State transition information
   - 构建结构化 FSM 安全状态转换图 $G_{ST} = (S, E)$

2. **Structured FSM Graph Analysis** (Algorithm 1):
   - **Phase 1 — Structural Vulnerability Identification** ( $G_{ST} \rightarrow V_S$ ): 遍历每条 transfer triple $(s_i, e, s_j)$，提取完整特征向量 $F(s_i, e, s_j)$，匹配结构规则 $\delta \in V_{struct}$，识别 Dead States、Unreachable Transitions 等拓扑缺陷。
   - **Phase 2 — Potential Vulnerability Identification** ( $G_{ST} \rightarrow V_P$ ): 提取部分特征 $F'(s_i, e, s_j)$，匹配潜在漏洞规则 $\pi \in V_{pot}$，标记 [[CWE-190]]（Integer Overflow）等需语义确认的漏洞候选。

**Stage II: Knowledge-guided Vulnerability Confirmation**

- **Potential Vulnerability Confirmation**: 对 $V_P$ 中每个候选，通过 [[Cypher]] 查询检索 [[FSKG]] 中的 confirm/confirm positive/confirm negative 知识，用 [[Few-shot Prompting|few-shot]] 推理确认 $V_P^C$。
- **Vulnerability Knowledge Retrieval**: 从 [[FSKG]] 直接检索对应缓解知识：$(V_P^C, V_S \rightarrow K_C)$，跳过中间安全报告阶段，将确认的漏洞知识操作化为生成时约束。

#### 模块3: Knowledge-guided Secure FSM Code Generation

**Security Prompt Construction**: 
- Functional prompt $P$: 固定模板（I/O interface, state encoding, transition logic, update logic, output logic + few-shot examples）
- Security prompt $K_C$: 仅来源于 [[FSKG]] 的确认漏洞缓解知识
- 拼接得到安全约束提示: $K_C + P \rightarrow P_{Se}$

**VcF Generation and Verification**:
- 功能性验证：检查生成的 FSM 是否满足指定行为
- 安全性验证：检查确认的漏洞是否被正确缓解
- 对于不安全需求，先生成功能正确代码 → 提供安全建议 → 呈现修订版代码

---

## 关键公式

### 公式1: [[Finite State Machine|FSM 形式化定义]]

$$
\text{FSM} = (S, I, O, s_0, \Omega, \gamma)
$$

**含义**: FSM 的 6 元组数学定义。

**符号说明**:
- $S$: 状态集合
- $I$: 输入集合
- $O$: 输出集合
- $s_0$: 初始状态（reset state）
- $\Omega: S \times I \rightarrow S$: 状态转换函数
- $\gamma$: 输出函数

### 公式2: Mealy FSM 输出函数

$$
\gamma: S \times I \rightarrow O
$$

**含义**: Mealy 型 FSM 输出同时取决于当前状态和输入。

### 公式3: Moore FSM 输出函数

$$
\gamma: S \rightarrow O
$$

**含义**: Moore 型 FSM 输出仅取决于当前状态。

### 公式4: [[State Transition Graph|状态转换图 (STG)]]

$$
G_{ST} = (S, E), \quad t = T(S_i, S_j)
$$

**含义**: FSM 的有向图表示，顶点 $S$ 表示状态，边 $E$ 表示状态转换。

### 公式5: Safety Prompt Construction

$$
K_C + P \rightarrow P_{Se}
$$

**含义**: 将 [[FSKG]] 检索到的安全知识 $K_C$ 与功能提示模板 $P$ 拼接为安全约束提示 $P_{Se}$。

**符号说明**:
- $K_C$: 确认漏洞对应的缓解知识（manner + suggestions）
- $P$: 功能性提示模板（I/O, state encoding, transitions, few-shot）
- $P_{Se}$: 安全约束生成提示

### 公式6: Security Metric

$$
\text{Sec} = \begin{cases} \text{Pass} & \text{if } \exists \text{ at least 1 of 5 candidates passes security check} \\ \text{Fail} & \text{otherwise} \end{cases}
$$

**含义**: 安全指标——5 次生成中至少 1 次通过安全检查即算通过。

### 公式7: Function Metric

$$
\text{Fun} \in \{0, 1, 2, 3, 4, 5\}
$$

**含义**: 功能指标——5 次试验中通过功能测试的次数。

---

## 关键图表

![Figure 1: State Transition Graph (STG)](https://doi.org/10.1109/TDSC.2026.3679566#figure-1)

> 展示某一控制 FSM 的状态转换图。顶点 $S_A, S_B, S_C$ 表示三个状态，边 $T_1\sim T_6$ 表示状态转换条件。

![Figure 2: Hazards Caused by VcF Vulnerabilities](https://doi.org/10.1109/TDSC.2026.3679566#figure-2)

> 展示 Verilog FSM 代码中漏洞后果：① Unreachable State → [[硬件木马|Hardware Trojan]] 插入 ② Missing default（[[CWE-1245]]）→ DoS

![Figure 3: Overall Pipeline of SecFSM](https://doi.org/10.1109/TDSC.2026.3679566#figure-3)

> SecFSM 完整流水线：Part 1 → 结构化 FSM 图分析 + 知识引导漏洞确认；Part 2 → 安全提示构建 → Verilog 代码生成 → 双重验证。

![Figure 4: FSM State Information Extraction Process](https://doi.org/10.1109/TDSC.2026.3679566#figure-4)

> (a) 用户需求 $R$ (b) 状态转换信息表格 (c) 安全状态转换图 $G_{ST}$

![Figure 5: Composition of Test Data](https://doi.org/10.1109/TDSC.2026.3679566#figure-5)

> 52 测试用例来源：[[VerilogEval]] (12) · [[ARC-FSM]] (12) · [[RTLLM]] (8) · Industrial FSM (13) · Artificial (7)

![Figure 6: Security-Enhanced Review Generation Performance](https://doi.org/10.1109/TDSC.2026.3679566#figure-6)

> 修订代码性能：[[DeepSeek-R1]] 96% (23/24) > Claude 3.5 88% > GPT-4o 79%

![Figure 7: Evaluation of Different Models](https://doi.org/10.1109/TDSC.2026.3679566#figure-7)

> 三模型 × 三方法（Base, RAG, SecFSM）对比：(a) 功能性 (b) 安全性

| Method | GPT-4o | Claude 3.5 | DeepSeek-R1 |
|--------|--------|------------|-------------|
| Base Fun | 10% | 73% | 97% |
| RAG Fun | 63% | 82% | 97% |
| SecFSM Fun | 87% | 98% | 98% |
| Base Sec | 3/52 | 15/52 | 19/52 |
| RAG Sec | 16/52 | 18/52 | 19/52 |
| SecFSM Sec | 39/52 | 46/52 | 48/52 |

![Figure 8: Structure-aware FSM Graph Analysis](https://doi.org/10.1109/TDSC.2026.3679566#figure-8)

> Stage I 漏洞提取精度：Base 47-68% → +Stage I 96-98%

| Model | P Base→+S1 | R Base→+S1 | F1 Base→+S1 |
|-------|-------------|-------------|--------------|
| GPT-4o | 68%→98% | 65%→98% | 66.5%→98.0% |
| Claude 3.5 | 64%→98% | 63%→96% | 63.5%→96.0% |
| DeepSeek-R1 | 47%→96% | 59%→96% | 52.3%→96.0% |

![Figure 9: Probability of Generating Secure Prompts](https://doi.org/10.1109/TDSC.2026.3679566#figure-9)

> 安全提示生成成功率（Trans / Output / Both）：GPT-4o 98%·98%·98%，Claude 3.5 94%·87%·90%，DeepSeek-R1 94%·85%·89%

![Figure 10: Case Study — TopModule](https://doi.org/10.1109/TDSC.2026.3679566#figure-10)

> 用户需求 → $G_{ST}$ → 漏洞列表（Dead State）→ [[FSKG]] 知识检索 → 安全提示词（GoodExample, subtasks）完整案例

### Table I: Knowledge Graph Node Relationships in FSKG

| Node Type | Relationships |
|-----------|---------------|
| FSM Vulnerability Level (N=23) | `Vulnerability → [:stage]`, `Vulnerability → [:type]` |
| Vulnerability Semantics Level (N=70) | `Vulnerability → [:Check]`, `Vulnerability → [:Consequence]`, `Vulnerability → [:GoodExample]`, `Vulnerability → [:BadExample]`, `confirm → [:confirm positive]`, `confirm → [:confirm negative]` |
| Mitigation and Secure Design Pattern Level (N=18) | `Vulnerability → [:suggestions]`, `suggestions → [:manner]` |

### Table II: Description of Vulnerabilities and Number of States

| Dataset | State Number | Cases | Vulnerability Type |
|---------|-------------|-------|--------------------|
| [[VerilogEval]] | 7 q2fsm∗, 4 fsm3s∗, 5 fsm3†, 7 q2fsm†, 4 fsm1s†, 5 fsm3s†, 10 fsmonehot†, 9 fsm2s†, 6 q3bfsm†, 2 fsm1△, 2 fsm1s△, 4 fsm3△, 4 fsm3s△ | 12 cases | ∗ coding, † struct, △ potential |
| [[ARC-FSM]] | 3 ARC(1), 1 ARC(1)△, 3 ARC(2)∗, 3 ARC(2)†, 3 ARC(3)†, 3 ARC(3)△ | 12 cases | ∗ coding, † struct, △ potential |
| [[RTLLM]] | 7 FSM†, 6 FSM△, 5 SQ Detector†, 5 SQ Detector(1)△, 5 SQ Detector(2)△, 6 SHA-512†, 6 AES† | 8 cases | † struct, △ potential |
| Industrial FSM | 9 PICO(a)†, 5 PICO(b)†, 5 PICO(c)†, 5 227†, 4 495∗, 5 601△, 4 633△ | 13 cases | ∗ coding, † struct, △ potential |
| Artificial Dataset | 4 995∗ | 7 cases | ∗ coding, † struct, △ potential |

**标记说明**: `∗` = coding vulnerabilities (e.g., Hamming Distance); `†` = structural vulnerabilities (e.g., Dead State); `△` = potential vulnerabilities (e.g., CWE-190).

### Table III: Overall Performance

| Model | Method | Fun Pass Rate | Sec Pass Rate |
|-------|--------|---------------|---------------|
| GPT-4o | Base | 10% (5/52) | 6% (3/52) |
| GPT-4o | +RAG | 63% (33/52) | 31% (16/52) |
| GPT-4o | SecFSM | 87% (45/52) | 75% (39/52) |
| Claude 3.5 | Base | 73% (38/52) | 29% (15/52) |
| Claude 3.5 | +RAG | 82% (43/52) | 35% (18/52) |
| Claude 3.5 | SecFSM | 98% (51/52) | 88% (46/52) |
| DeepSeek-R1 | Base | 97% (50/52) | 37% (19/52) |
| DeepSeek-R1 | +RAG | 97% (50/52) | 37% (19/52) |
| DeepSeek-R1 | SecFSM | 98% (51/52) | 92% (48/52) |

Inter-annotator agreement: $\kappa = 0.974$ (overall), $\kappa = 1.000$ (Base), $\kappa = 0.985$ (RAG), $\kappa = 0.879$ (SecFSM).

### Table IV: Ablation Study

| Model | Configuration | Fun Pass Rate | Sec Pass Rate |
|-------|---------------|---------------|---------------|
| GPT-4o | – Stage II | 88% | 69% (36/52) |
| GPT-4o | – Stage I | 94% | 46% (24/52) |
| GPT-4o | – Both Stages | 85% | 33% (17/52) |
| GPT-4o | **Full (Stage I+II)** | **87%** | **75% (39/52)** |
| DeepSeek-R1 | – Stage II | 98% | 71% (37/52) |
| DeepSeek-R1 | – Stage I | 98% | 44% (23/52) |
| DeepSeek-R1 | – Both Stages | 98% | 37% (19/52) |
| DeepSeek-R1 | **Full (Stage I+II)** | **98%** | **92% (48/52)** |

Inter-annotator agreement: $\kappa = 0.951$ (overall), $\kappa = 0.943$ (GPT-4o), $\kappa = 0.958$ (DeepSeek-R1).

**关键发现**:
- Stage II 对编码安全（coding vulnerabilities）至关重要：移除后 GPT-4o 安全率从 75% 降至 69%
- Stage I 对结构性漏洞（Dead State）不可或缺：LLM 纯文本方式无法可靠检测
- Full (Stage I+II) 代表 Baseline (Base LLM without any stage, ~19/52)
- 两阶段方法论对安全提升贡献最大

---

## 实验结果

### 数据集

| 数据集来源 | 案例数 | 特点 | 用途 |
|------|------|------|------|
| [[VerilogEval]] | 12 | 学术基准，8 states 以内 | 功能+安全评估 |
| [[ARC-FSM]] | 12 | 自动安全规则检查基准 | 结构性漏洞评估 |
| [[RTLLM]] | 8 | 开源 RTL 基准 | 复杂状态机评估 |
| Industrial FSM | 13 | 真实工业 FSM (PICO, SHA-512, AES) | 工业适用性评估 |
| Artificial Dataset | 7 | 人工构建的安全测试数据 | 编码漏洞评估 |

**漏洞注入**: Algorithm 2 (TRIGGERCHECK 确保漏洞功能可达 + HumanCheck 人工审核 + Recipe 随机选择)

### 实现细节

- **LLM Backbones**: [[GPT-4o]], [[Claude 3.5]], [[DeepSeek-R1]]
- **Decoding Temperature**: 统一设为 0.2（低温度确保稳定性和可复现性）
- **RAG Baseline**: [[TinyRAG]]，检索 top-k=1，固定长度分块（600 tokens/chunk，150 tokens overlap）
- **Few-shot Examples**: 在功能提示和安全确认阶段均使用
- **评测指标**: Fun (0–5 次功能测试通过数), Sec (5 次中≥1 次安全通过), [[Cohen's Kappa|Cohen's $\kappa$]] (标注一致性)
- **安全评估**: 两位安全训练标注员独立盲评（Secure / Insecure），不一致时第三位专家裁决

### 主要结果

**RQ1 (Overall Effectiveness)**: SecFSM 在所有模型上显著超越 Baseline。
- [[GPT-4o]]: Base 3/52 → SecFSM 39/52
- [[Claude 3.5]]: Base 15/52 → SecFSM 46/52
- [[DeepSeek-R1]]: Base 19/52 → SecFSM 48/52 (best)

**RQ2 (Ablation)**:
- Stage II 移除: GPT-4o 安全 75%→69%，失去对 coding vulnerabilities 的缓解能力
- Stage I 移除: GPT-4o 安全 75%→46%，无法检测 Dead State 等结构性缺陷
- Stage I+II 均移除: 等效 Base LLM，安全仅 33%（GPT-4o）/ 37%（DeepSeek-R1）

**RQ3 (LLM Impact)**: 功能性随 LLM 能力显著变化（GPT-4o Base 10% vs DeepSeek-R1 97%），但安全性对所有商用 LLM 均为主要瓶颈。SecFSM 作为模型无关方法论，对所有模型均有效。

**RQ4 (Failure Analysis)**:
- Stage I 错误主要来源于：极度隐式或领域特定的安全描述、FSKG 中稀疏的罕见状态-输入组合
- Stage II: 平均成功率 3/5，ARC△ 仅 1/5（算术+控制流交织，安全知识分散在多节点/多关系中）
- 安全提示生成: GPT-4o 98% 成功率，Claude 3.5/DeepSeek-R1 约 85-94%
- 瓶颈转移: 从"分析什么漏洞"到"如何完整精确地集成知识"

---

## 批判性思考

### 优点

1. **端到端系统性**: 从知识图谱构建 → 需求分析 → 漏洞确认 → 安全生成 → 双重验证，形成了完整的 secure-by-design 流水线
2. **模型无关性**: 在 [[GPT-4o]]、[[Claude 3.5]]、[[DeepSeek-R1]] 三个不同架构的 LLM 上均有显著提升，方法通用性强
3. **结构化方法论**: 将安全知识从 LLM 的黑盒隐式记忆外化为显式、可检索、可推理的知识图谱
4. **开源**: 数据集和实现在 GitHub 开源，可复现性高

### 局限性

1. **[[FSKG]] 依赖人工构建**: 知识图谱的质量完全依赖专家手动清理和对齐，扩展性和维护成本需要持续关注
2. **FSM 特异性**: 方法深度耦合 FSM 结构（状态转换图、Dead State 等），扩展到其他硬件模块（加密控制器、总线等）需要重新设计本体
3. **推理开销**: 相比单次 LLM 调用增加了多次交互和知识图谱查询，延迟较高
4. **Cypher 查询链路脆弱性**: 安全知识检索受前置步骤影响，多跳子图检索不完整会导致规则不完整
5. **数据集规模**: 52 个案例覆盖面有限，偏重特定类型的 FSM 漏洞

### 潜在改进方向

1. **自动/半自动 FSKG 扩展**: 利用 LLM 辅助从新 CWE 条目自动生成 FSM 级漏洞知识，降低维护成本
2. **多跳子图检索优化**: 改进 [[Cypher]] 查询的完整性，确保安全知识不因子图缺失而被遗漏
3. **跨模块泛化**: 将安全知识图谱范式推广到加密模块、总线互连等其他硬件 IP
4. **侧信道集成**: 增加微架构/侧信道安全语义层（如功耗分析、时序攻击），扩大安全覆盖面
5. **更大规模基准**: 建立标准化 FSM 安全生成基准，覆盖更多漏洞类型和复杂度的设计

### 可复现性评估
- [x] 代码开源 (https://github.com/ZitengHu/SecFSM)
- [ ] 预训练模型不适用（方法使用商用 API LLMs）
- [x] 数据集可获取（开源）
- [x] 训练细节完整（temperature=0.2, TinyRAG 参数, top-k=1）
- [x] 实验可复现性高（双审标注 + Cohen's Kappa 验证）

---

## 关联笔记

### 基于
- [[LLM]]: 底层代码生成引擎
- [[RAG]]: 检索增强基线方法
- [[CWE]]: 漏洞分类知识来源

### 对比
- [[VerilogCoder]]: 功能导向的 Verilog 生成，忽视安全
- [[RTLCoder]]: 轻量 RTL 代码生成，无安全约束
- [[ChipNeMo]]: 芯片领域 LLM 助手，主要针对问答和调试

### 方法相关
- [[FSKG]]: 本文核心知识图谱组件
- [[Cypher]]: 知识图谱查询语言
- [[AutoGen]]: 用于多智能体安全代码修订
- [[ARC-FSM]]: FSM 安全规则自动检查基准

### 硬件/安全相关
- [[VerilogEval]]: Verilog 代码评估基准
- [[SoC]]: 应用场景
- [[Finite State Machine|FSM]]: 核心生成目标
- [[CWE-1245]]: FSM missing default 漏洞
- [[CWE-190]]: Integer Overflow 漏洞
- [[Hardware Trojan]]: 攻击场景

---

## 速查卡片

> [!summary] SecFSM: KG-Guided LLMs for Secure Verilog FSM Generation
> - **核心**: 构建 [[FSKG]] 知识图谱，在代码生成前进行两阶段漏洞分析，以安全约束提示引导 LLM 生成安全 FSM
> - **方法**: FSKG (111 nodes/161 edges) + Two-stage Vulnerability Analysis + Security Prompting
> - **结果**: [[DeepSeek-R1]] 安全通过 48/52 (92%)，远超 Base (19/52) 和 RAG (19/52)
> - **代码**: https://github.com/ZitengHu/SecFSM

---

*笔记创建时间: 2026-06-23*
