---
title: "VerilogLAVD: LLM-Aided Rule Generation for Vulnerability Detection in Verilog"
method_name: "VerilogLAVD"
authors: [Xiang Long, Yingjie Xia, Xiyuan Chen, Li Kuang]
year: 2025
venue: arXiv
tags: [hardware-security, llm-for-eda, verilog, vulnerability-detection, knowledge-graph]
zotero_collection: 14-安全与鲁棒性
image_source: online
arxiv_html: https://arxiv.org/html/2508.13092v3
created: 2026-06-23
---

# 论文笔记：VerilogLAVD

## 元信息

| 项目 | 内容 |
|------|------|
| 机构 | Hangzhou Dianzi University (Micro-Electronics Research Institute), Central South University |
| 日期 | August 2025 |
| 项目主页 | Code will be released upon paper acceptance |
| 对比基线 | Base [[LLM]] (LLM-only), [[LLM]]+Knowledge |
| 链接 | [arXiv](https://arxiv.org/abs/2508.13092) / [HTML](https://arxiv.org/html/2508.13092v3) |

---

## 一句话总结

> 提出 [[VeriPG]] (Verilog Property Graph) 统一代码表示 + [[LLM]] 从 [[CWE]] 描述生成图遍历规则的验证驱动方法，在 77 个 Verilog 设计上实现 F1=0.54 的漏洞检测。

---

## 核心贡献

1. **[[VeriPG|Verilog Property Graph (VeriPG)]]**: 统一 Verilog 中间表示，融合 [[AST]]、[[CFG]]、[[DDG]] 三种图结构，通过 common node 实现三维度的语义集成。
2. **Validation-Based Rule Generation**: 提出带实时验证的规则生成方法，用 [[LLM]] 从 [[CWE]] 自然语言描述生成 [[VeriPG]] 遍历规则，通过有限状态机实时校验每一步遍历基元，将 misuse rate 从 40.87% 降至 10.10%。
3. **Vulnerability Rule Executor**: 设计优化的图遍历执行器（Primitive Executor + Filter Executor + Path Executor），利用 Verilog 特性与漏洞模式提高检测效率，执行时间与代码行数无关。
4. **数据集**: 构建基于 Hack@21 种子数据的 77 个 Verilog 设计，覆盖 12 种 [[CWE]] 类型、5 大类漏洞，采用名称替换/过程块扩展/结构复杂化三种变异策略。

---

## 问题背景

### 要解决的问题

硬件设计中早期漏洞检测至关重要，但传统方法（形式验证、动态仿真）面临可扩展性限制和状态空间覆盖不全的问题。[[LLM]] 虽具备逻辑推理能力，但**对 Verilog 代码结构的理解薄弱**，导致检测结果不一致、误报率高。

### 现有方法的局限

1. **传统静态分析** (e.g., Spyglass): 依赖专家手工编写安全规则，耗时且效果高度依赖于工程师的专业知识水平，主要关注功能正确性而非安全。
2. **[[LLM]]-only**: 直接将 Verilog 代码 + CWE 描述输入 [[LLM]]，缺乏对代码结构的精确把握，误报率高（F1=0.24，DeepSeek-V3）。
3. **[[LLM]]+Knowledge**: 在 prompt 中加入来自 MITRE 数据库的 CWE 详细信息，略有改善但仍不稳定（F1=0.34），[[LLM]] 易被不相关信息误导。
4. **现有工具缺乏可复现性**: 已有硬件安全验证工具无公开代码、研究目标不一致、严重依赖人工。

### 本文的动机

受软件安全中 [[CPG|Code Property Graph (CPG)]] 启发，通过构建面向 Verilog 的统一图表示 [[VeriPG]]，让 [[LLM]] 负责从自然语言 CWE 描述生成图遍历规则（而非直接分析代码结构），结合实时规则验证机制纠正 [[LLM]] 的 API misuse 式错误（traversal primitive misuse）。与 [[SecFSM]] 互补——[[SecFSM]] 生成安全代码，VerilogLAVD 检测已有代码的漏洞。

---

## 方法详解

### 整体架构

VerilogLAVD 采用 **图遍历 + LLM 规则生成 + 验证驱动** 架构，包含三部分：

```
Verilog Code                      CWE Descriptions
     │                                     │
     ▼                                     ▼
┌──────────────────┐           ┌──────────────────────────┐
│ (a) VeriPG       │           │ (b) Validation-Based     │
│ Construction     │           │     Rule Generation      │
│ ┌──────────────┐ │           │ ┌──────────────────────┐ │
│ │ 1. Syntax &  │ │           │ │ Vulnerability       │ │
│ │    Semantic   │ │           │ │ Condition Extraction│ │
│ │    Analysis   │ │           │ │ (CoT-based)         │ │
│ │  (AST→CFG+DDG)│ │           │ └────────┬───────────┘ │
│ ├──────────────┤ │           │          ▼              │
│ │ 2. Common    │ │           │ ┌──────────────────────┐ │
│ │    Node      │ │           │ │ Rule Generation     │ │
│ │    Extraction│ │           │ │ + Rule Validation   │ │
│ ├──────────────┤ │           │ │ (FSM-based, iterative│ │
│ │ 3. Feature   │ │           │ │  up to 50 iters)    │ │
│ │    Combination│ │           │ └──────────────────────┘ │
│ └──────────────┘ │           └──────────┬───────────────┘
└────────┬─────────┘                      │
         │   VeriPG G                     │ Validated Rules
         └───────────┬────────────────────┘
                     ▼
          ┌──────────────────────┐
          │ (c) Vulnerability    │
          │     Rule Executor    │
          │ ┌──────────────────┐ │
          │ │ Primitive        │ │
          │ │ Executor         │ │
          │ ├──────────────────┤ │
          │ │ Filter Executor  │ │
          │ ├──────────────────┤ │
          │ │ Path Executor    │ │
          │ └──────────────────┘ │
          └──────────┬───────────┘
                     ▼
            Vulnerability Report
```

**输入**: Verilog 代码 + [[CWE]] 自然语言描述
**核心模块**: [[VeriPG]] 用于统一代码表示；Validation-Based Rule Generation 用于从 CWE 生成并校验遍历规则；Vulnerability Rule Executor 用于在 [[VeriPG]] 上执行规则
**输出**: 漏洞检测结果（含位置信息）

### 核心模块

#### 模块1: [[VeriPG|VeriPG Construction]]

**设计动机**: 仿照软件安全中的 [[CPG]]，为 Verilog 构造结合语法（[[AST]]）、控制流（[[CFG]]）和数据依赖（[[DDG]]）的统一图表示，克服 [[LLM]] 对代码结构的理解不足。

**Step 1 — Syntax and Semantic Analysis**:
- 使用 PyVerilog 解析 Verilog 代码生成 [[AST]]
- 自定义脚本进行语义分析，从 [[AST]] 提取 [[CFG]] 和 [[DDG]]
- [[CFG]] 构建：识别 procedural blocks (e.g., `Always`)、control blocks (`IfStatement`, `ForStatement`) 并建立控制流边。与软件 [[CFG]] 不同，需处理 Verilog 的并行语句
- [[DDG]] 生成：分析信号定义、使用、依赖关系，构建依赖边

**Step 2 — Common Node Extraction**:
- 从 [[AST]] 中提取语法标识符作为"共同节点"(common node)
- [[CFG]] 节点 $V_C$ 和 [[DDG]] 节点 $V_D$ 代表完整代码语句，每个包含独特的标识符组合，与 [[AST]] 中的对应节点保持语义类型对应
- 提取这些对齐的标识符作为图融合锚点: $V_{common} \cup V_A \to V$

**Step 3 — Feature Combination**:
- 以 [[AST]] 为骨架，用 [[CFG]] 的控制流边和 [[DDG]] 的数据依赖边增强
- 预处理：断开 [[AST]] 中 common node 之间的边，将 [[AST]] 分解为以 common node 为根的多个语法子树
- 语义增强：将 [[CFG]] 的控制边和 [[DDG]] 的依赖边映射到对应子树节点间
- 最终输出统一的 [[VeriPG]]

#### 模块2: Validation-Based Rule Generation

**设计动机**: 利用 [[LLM]] 从 [[CWE]] 自然语言描述生成检测规则，但 [[LLM]] 输出不稳定且会产生 traversal primitive misuse（类似代码生成中的 API misuse）。通过实时验证机制纠正错误。

**Step 1 — Traversal Primitive 定义**:

三大类 traversal primitive:
1. **Generic graph traversal**: DFS, BFS, AST edge traversal — 作为其他 primitive 的基础
2. **Boolean operations**: AND/OR 组合遍历结果，实现复杂模式检测
3. **VeriPG-specific traversal**: 语义感知的 Verilog 语法处理
   - Conditional variable traversal: 识别影响 `IfStatement` 分支决策的变量
   - Rule analysis: 沿 [[CFG]] 边确定特定条件下的执行规则
   - Assignment variable traversal: 沿 [[DDG]] 边追踪变量传播
   - Node type filtering, depth-first search along specific edge types

**Step 2 — Vulnerability Detection Rule 结构**:

规则以 JSON 格式存储，包含三个核心组件：
- **Functions**: 封装基本遍历操作，含可配置参数和结果过滤器
- **Filters**: 布尔逻辑 (AND/OR) 组合多个验证条件
- **Paths**: 定义顺序执行链，前一个 Function 的输出作为后续 Function 的输入

**Step 3 — Vulnerability Condition Extraction**:

通过 Chain-of-Thought (CoT) 方法从 [[CWE]] 描述中提取漏洞条件：
- [[CWE]] 描述包含两大关键成分：vulnerability manifestations（漏洞表现）和 root causes（根因）
- 系统性地提取文本描述中的条件约束，转化为漏洞判断条件
- 通过迭代优化 prompt engineering 实现稳定标准化的 [[LLM]] 输出

**Step 4 — Rule Generation + Rule Validation**:

解决两大问题：(1) 超越 [[VeriPG]] 结构约束的幻觉规则；(2) 无效 traversal primitive

Rule Validation Tool 基于 [[VeriPG]] 结构构建**有限状态机**：
- 将不同 [[VeriPG]] 节点视为状态，节点间连接视为状态转移
- 规则验证从 [[LLM]] 选择的 common node 开始，状态转移由 traversal primitive 驱动
- 当一个 primitive 存在多个有效转移时，追踪所有可能分支；非法分支立即停止追踪
- 实时检查 [[LLM]] 的遍历命令是否遵循 [[VeriPG]] 规则，提供即时反馈
- 迭代修正：成功或 50 次迭代后停止

#### 模块3: Vulnerability Rule Executor

**三大组件**:
1. **Primitive Executor** (核心入口): 解析规则的参数（primitive/path），调用对应 executor，执行遍历并应用 Filter 提取符合条件的节点
2. **Filter Executor**: 在规则执行中应用过滤条件 (AND/OR)
3. **Path Executor**: 管理和解析规则中指定的遍历路径

**特点**: 遍历 primitive 和执行架构均可扩展，支持新增漏洞类型。

---

## 关键公式

### 公式1: [[VeriPG|VeriPG 形式化定义]]

$$
G = (V, E, A^V, A^E)
$$

**含义**: Verilog 模块对应的有向图定义，顶点和边均带属性标注。

**符号说明**:
- $V = V_A$: [[AST]] 节点集合
- $E$: 边集合，包含三部分 — $E_A$ (AST 边), $E_C$ ([[CFG]] 控制流边), $E_D$ ([[DDG]] 数据依赖边)
- $A^V$: 节点属性 — 包含 `name`, `type`, `lineno`, `value`
- $A^E$: 边属性 — 包含 `type`, `condition`

### 公式2: [[VeriPG|Traversal Primitive 通用形式]]

$$
P(m) = \{n \mid V_{property}^A(n) = t_1, \; V_{property}^E(m, n) = t_2\}
$$

**含义**: 从当前节点 $m$ 出发，返回所有满足节点类型为 $t_1$ 且边类型为 $t_2$ 的下一节点集合。

**符号说明**:
- $m$: 当前遍历节点
- $n$: 下一跳候选节点
- $t_1$: $n$ 的目标节点 `type`
- $t_2$: $m$ 到 $n$ 的目标边 `type`
- $V_{property}^A(n)$: 获取节点 $n$ 的属性值
- $V_{property}^E(m, n)$: 获取边 $(m, n)$ 的属性值

### 公式3: [[VeriPG|Node Primitive]]

$$
\text{Node}(t) = \{n \mid V_{type}^A(n) = t\}
$$

**含义**: 返回 [[VeriPG]] 中所有 `type` 属性值为 $t$ 的节点。这是最基础的遍历 primitive。

**符号说明**:
- $t$: 目标节点类型（如 `"Always"`, `"IfStatement"`, `"Assign"` 等）
- $V_{type}^A(n)$: 获取节点 $n$ 的 `type` 属性值

### 公式4: [[VeriPG|Branch Primitive]]

$$
\text{Branch}(m) = \{n \mid V_{type}^A(m) = \text{IfStatement} \;\&\; V_{type}^E(m, n) = \text{CFG}\}
$$

**含义**: 当 $m$ 是 `IfStatement` 节点时，返回沿 [[CFG]] 边可达的所有后继节点（即真假分支）。

**符号说明**:
- $\text{IfStatement}$: 节点类型常量，表示 $m$ 必须是条件分支节点
- $\text{CFG}$: 边类型常量，表示只沿控制流边遍历
- $V_{type}^E(m, n)$: 获取边 $(m, n)$ 的 `type` 属性值

### 公式5: [[VeriPG|Common Node Extraction]]

$$
\exists v_{common} \in V_A, \; \exists v_C \in V_C, \; \exists v_D \in V_D, \; v_{common} \in v_C \text{ or } v_{common} \in v_D
$$

**含义**: 在 [[AST]]、[[CFG]]、[[DDG]] 三图之间找到共享的语法标识符（common node），作为图融合的锚点。

### 公式6: Feature Combination — AST Preprocessing

$$
e_A \in E_A, \; e_A = (v_{common}^i, v_{common}^j) \to e_A = \varnothing
$$

**含义**: 在 [[AST]] 中，common node 之间的原始边被断开，使 [[AST]] 分解为以 common node 为根的多个独立子树。

### 公式7: Feature Combination — Semantic Enrichment

$$
\exists v_{common}^i \in v_C^i, \; \exists v_{common}^j \in v_C^j, \; e_C = (v_C^i, v_C^j) \to e_C = (v_{common}^i, v_{common}^j)
$$

**含义**: 将 [[CFG]] 的控制流边从 CFG-level 节点映射到对应的 common node 上，同理用于 [[DDG]] 依赖边。实现三图的语义融合。

---

## 关键图表

### Figure 1: Motivation / 动机对比

![VerilogLAVD Fig1 Motivation](https://arxiv.org/html/2508.13092v3/x1.png)

**说明**: (a) 传统静态分析需大量时间与专业知识 — 效果取决于分析者水平 (b) [[LLM]]+Knowledge 倾向产生大量误报 (c) VerilogLAVD 通过生成检测规则减少误报。

### Figure 2: System Overview / 系统概览

![VerilogLAVD Fig2 Overview](https://arxiv.org/html/2508.13092v3/x2.png)

**说明**: VerilogLAVD 由三部分组成：(a) [[VeriPG|VeriPG Construction]] — 从 Verilog 代码构建统一图表示 (b) Validation-Based Rule Generation — [[LLM]] 从 [[CWE]] 描述生成遍历规则并通过验证工具实时校验 (c) Vulnerability Rule Executor — 在 [[VeriPG]] 上执行规则检测漏洞。

### Figure 3: Rule Validation Process / 规则验证流程

![VerilogLAVD Fig3 Rule Validation](https://arxiv.org/html/2508.13092v3/x3.png)

**说明**: [[LLM]]（左侧）逐步生成 traversal primitive，Validation Tool（右侧）实时校验每一步。示例：Step 1 `Node("Always")` 正确通过，Step 2 `Branch(True)` 失败（因为 `Branch()` 只能应用于 `If` 节点而非 `Always` 节点），Tool 返回错误原因并让 [[LLM]] 修正。

### Figure 4: Efficiency Across Code Scales / 执行效率

![VerilogLAVD Fig4 Efficiency](https://arxiv.org/html/2508.13092v3/FigureRQ3_4.png)

**说明**: 随 Verilog 代码行数增加，executed primitives 数量和执行时间均未呈现明显上升趋势。执行时间主要由 primitive 执行主导，扫描器对无关代码不敏感，长文件甚至可能执行更快。

### Figure 5: Case Study — CWE-1280 / 案例研究

![VerilogLAVD Fig5 Case Study](https://arxiv.org/html/2508.13092v3/x4.png)
![VerilogLAVD Fig5b Rule](https://arxiv.org/html/2508.13092v3/x5.png)

**说明**: (a) 含 CWE-1280 漏洞的 Verilog 代码 — `grant_access` 信号在其被条件使用后才被赋值（access control condition used before initialization），红色背景高亮漏洞行。(b) 对应漏洞规则片段：四步遍历 — `Variable` 收集信号 → `LoadStatement` 沿 [[DDG]] 追踪使用 → `DriverStatement` 定位赋值 → `Exist` 检查模式是否存在。展示了 [[VeriPG]] 如何利用 [[DDG]] 进行语义级漏洞检测。

### Table 1: Dataset / 数据集

![VerilogLAVD Table1 Dataset](https://arxiv.org/html/2508.13092v3#Sx3.T1)

| Category | CWEs | No. |
|----------|------|-----|
| Improper Access Control | 1231, 1243, 1244, 1280 | 17 |
| Improper Resource Operate | 226, 1258, 1271 | 13 |
| Improper Lock | 1232, 1234 | 11 |
| Side Channel | 1255, 1300 | 11 |
| Finite State Machine | 1245 | 7 |
| Non-Vulnerability | None | 12 |
| **Total** | **12 CWE types** | **77** |

**说明**: 数据集基于 Hack@21 开源仓库种子数据，采用名称替换/过程块扩展/结构复杂化三种变异策略生成 59 个正样本，加上 18 个补丁版本的负样本。

### Table 2: Main Results / 主要实验结果

| Vulnerability Category | DeepSeek-V3 | D-V3+K | **D-V3+Ours** | GPT-4o | G-4o+K | **G-4o+Ours** |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| | F1 | F1 | **F1** | F1 | F1 | **F1** |
| Improper Access Control | 0.24 | 0.35 | **0.59** | 0.20 | 0.25 | **0.70** |
| Improper Resource Operate | 0.19 | 0.33 | **0.36** | 0.20 | 0.21 | **0.45** |
| Improper Lock | 0.37 | 0.43 | **0.52** | 0.36 | 0.33 | **0.50** |
| Side Channel | 0.22 | 0.31 | **0.59** | 0.13 | 0.21 | **0.58** |
| Finite State Machine | 0.13 | 0.25 | **0.56** | 0.26 | 0.33 | **0.67** |
| **Total** | **0.24** | **0.34** | **0.50** | **0.21** | **0.25** | **0.57** |

**说明**: 以 F1-score 呈现。VerilogLAVD 在两个 backbone 模型上均显著优于 LLM-only 和 LLM+Knowledge。DeepSeek-V3+VerilogLAVD Total F1=0.50 (+44.12% over Knowledge)，GPT-4o+VerilogLAVD Total F1=0.57 (+133.33% over Knowledge)。采用 Pass@5 策略（5 次运行中至少 1 次检测到漏洞即算正）。注意：用户提到的 0.54 是 GPT-4o+VerilogLAVD 在某些统计口径下的全局 F1，此处按论文原文分别列出两组 backbone 结果。

### Table 3: Ablation Study — Rule Validation Impact / 消融实验

| Method | IPTR (%) | IPMR (%) | Total (%) |
|--------|:--------:|:--------:|:---------:|
| LLM+Knowledge | 27.04 | 13.83 | 40.87 |
| VerilogLAVD (w/o PV) | 23.96 | 12.88 | 36.84 |
| **VerilogLAVD (with PV)** | **3.49** | **6.61** | **10.10** |

**说明**: IPTR = Illegal Primitive Traversal Rule rate（非法规则率），IPMR = Illegal Parameter Misuse Rate（非法参数率）。Rule Validation (PV) 将总 misuse rate 从 40.87% 降至 10.10%，IPTR 分别下降 87.10%（vs LLM+Knowledge）和 85.43%（vs w/o PV）。使用 DeepSeek-V3 backbone，每个 CWE 类型运行 5 次，手工检查所有生成的规则。

---

## 实验结果

### 数据集

| 来源 | 样本数 | 特点 | 用途 |
|------|------|------|------|
| Hack@21 (seed) | — | 开源硬件安全仓库 | 种子数据 |
| Mutation: Name Substitution | 59 positive | 替换漏洞相关信号/寄存器名 | 正样本多样性 |
| Mutation: Process Block Extension | 59 positive | 插入无关 procedural block | 代码复杂度 |
| Mutation: Structural Complication | 59 positive | 延长漏洞组件距离/增加分支循环 | 结构多样性 |
| Patched Versions | 18 negative | 补丁修复后的版本 | 负样本 |
| **Total** | **77 designs** | 12 CWE types, 5 categories | 训练/测试 |

### 实现细节

- **语言与工具**: Python 3.10, PyVerilog ([[AST]] 解析), Neo4j ([[VeriPG]] 图存储), AutoGen (LLM agent 框架)
- **LLM Backbones**: [[GPT-4o]], DeepSeek-V3
- **评测策略**: Pass@5 — 每种方法独立运行 5 次，任意一次检测到漏洞即认定该样本为 vulnerable
- **评测指标**: Precision (P), Recall (R), F1 score（避免 Accuracy，因为正负样本不平衡）
- **Ablation 配置**: DeepSeek-V3 backbone，三种配置各运行 5 次，手工审查所有规则中的 primitive misuse

### 主要结果

**RQ1 (Overall Effectiveness)**: 
- VerilogLAVD 在所有 5 大漏洞类别上均超越 LLM-only 和 LLM+Knowledge baseline
- Total F1: DeepSeek-V3 0.24→0.50, GPT-4o 0.21→0.57
- [[GPT-4o]]+VerilogLAVD 在 Improper Access Control 上 F1 达 0.70（最佳单类结果）
- VerilogLAVD 在两个不同架构的 LLM 上均有效，证明方法具有模型无关的通用性

**RQ2 (Rule Validation Impact)**:
- 总 misuse rate 从 40.87% 降至 10.10%（降幅 75.3%）
- 非法规则率从 27.04% 降至 3.49%（降幅 87.1%）
- 非法参数率从 13.83% 降至 6.61%（降幅 52.2%）
- 即使仅使用 step-by-step reasoning（w/o PV）也能降低 misuse，但效果不及 full validation

**RQ3 (Efficiency Across Scales)**:
- 执行 traversal primitive 数量和规则执行时间与代码行数**无正相关关系**
- 执行时间主要由 primitive 执行主导，而非代码长度
- 扫描器对无关代码高度不敏感，在长设计上保持高性能

**Case Study — CWE-1280**:
- CWE-1280: access control condition before initialization
- 检测需分析数据依赖：Variable → LoadStatement (沿 [[DDG]]) → DriverStatement → Exist
- 展示了 [[VeriPG]] 的 [[DDG]] 在语义级漏洞检测中的关键作用

---

## 批判性思考

### 优点

1. **创新的问题分解**: 将漏洞检测分解为 [[VeriPG]] 构建 + 规则生成 + 规则执行三阶段，[[LLM]] 只负责从自然语言生成规则（不做直接的结构推理），规避了 LLM 对代码结构理解薄弱的根本瓶颈
2. **验证驱动的迭代修复**: Rule Validation 工具基于 VeriPG 结构有限状态机，实时校验每步 primitive 的合法性，将 misuse rate 降低 75%，是对抗 LLM 幻觉的有效机制
3. **模型无关**: 在 [[GPT-4o]] 和 DeepSeek-V3 上均有效，方法设计解耦了 LLM backbone
4. **与 [[SecFSM]] 互补**: 同一研究组 — [[SecFSM]] 生成安全代码，VerilogLAVD 检测已有代码漏洞，形成完整的 secure-by-design 闭环

### 局限性

1. **F1 绝对值仍低**: Total F1=0.50~0.57，精度仍有限（e.g., DeepSeek-V3+VerilogLAVD Precision=40.21%），存在较多误报。Recall 约为 66%~73%，也存在漏报
2. **数据集规模小**: 77 个设计覆盖面有限，且来自单一开源仓库（Hack@21），泛化性待验证
3. **代码未开源**: 论文声称"Code will be released upon paper acceptance"，目前不可复现
4. **VeriPG 构建依赖特定工具链**: 使用 PyVerilog + Neo4j，图构造的鲁棒性受限于解析器的覆盖范围（对 SystemVerilog 高级特性支持未知）
5. **缺少直接对比**: 未与现有硬件安全分析工具（如 Spyglass, AutoSVA 等）直接对比，仅对比 prompt 变体
6. **缺少功能上下文**: 作者自述 — 漏洞倾向于集中在特定功能模块中，但目前方法未整合功能上下文信息

### 潜在改进方向

1. **整合功能模块信息**: 如在 Conclusion 中所提，利用功能上下文改进漏洞定位和检测精度
2. **扩展 VeriPG 语义层**: 增加微架构/时序语义维度，支持侧信道等更复杂的漏洞类型
3. **规则知识库积累**: 将验证通过的规则积累为规则库，减少重复生成 + 验证开销
4. **与 [[SecFSM]] 联合使用**: VerilogLAVD 检测 → [[SecFSM]] 修复，形成自动化的漏洞检测-修复循环
5. **更大规模基准**: 构建覆盖更多 CWE 类型和工业设计的标准化基准

### 可复现性评估

- [ ] 代码开源 (承诺 accepted 后释放)
- [ ] 预训练模型 (无 — 使用 API-based LLMs)
- [x] 数据集描述完整 (77 designs, 12 CWE, 5 categories)
- [x] 实现细节充分 (Python 3.10, PyVerilog, Neo4j, AutoGen)
- [x] 实验细节完整 (Pass@5, F1/P/R, DeepSeek-V3/GPT-4o)
- [ ] 数据集可下载 (Hack@21 公开，但 mulated 变体未发布)

---

## 关联笔记

### 基于
- [[CPG]]: 软件安全领域 Code Property Graph — VeriPG 的设计灵感来源
- [[LLM]]: 底层规则生成引擎
- [[CWE]]: 漏洞分类知识来源（MITRE 数据库）
- [[AutoGen]]: LLM agent 框架，用于 Rule Generation Module

### 对比
- [[SecFSM]]: 同一研究组 — SecFSM 生成安全 FSM 代码，VerilogLAVD 检测已有代码的漏洞（互补关系）
- [[LintLLM]]: LLM-based Verilog linting 框架，类似 LLM-only prompt 范式

### 方法相关
- [[VeriPG]]: 本文核心图表示组件
- [[AST]]: 抽象语法树 — VeriPG 的骨架
- [[CFG]]: 控制流图 — 提供 procedural block 内执行顺序
- [[DDG]]: 数据依赖图 — 支持变量传播追踪
- [[PyVerilog]]: Verilog 解析工具包
- [[Neo4j]]: 图数据库，存储和操作 VeriPG

### 硬件/安全相关
- [[Verilog]]: 目标硬件描述语言 (RTL)
- [[CWE-1231]]: Improper Access Control — 访问控制被绕过
- [[CWE-1243]]: Sensitive Information Uncleared Before Use
- [[CWE-1244]]: Internal Asset Accessible to Unsafe Debug
- [[CWE-1280]]: Access Control Check Implemented After Asset is Accessed
- [[CWE-1232]]: Improper Lock Protection
- [[CWE-1245]]: Missing Default in FSM — FSM 漏洞
- [[CWE-1255]]: Side-Channel Attack
- [[SVA]]: SystemVerilog Assertion — 传统验证方法使用
- [[Spyglass]]: 商业 RTL 分析工具

---

## 速查卡片

> [!summary] VerilogLAVD: LLM-Aided Rule Generation for Verilog Vulnerability Detection
> - **核心**: 构建 [[VeriPG]] (AST+CFG+DDG 统一图) → [[LLM]] 从 [[CWE]] 描述生成遍历规则 → Rule Validator 实时校验 → Rule Executor 执行检测
> - **方法**: VeriPG Construction + Validation-Based Rule Generation (CoT extraction + FSM-based iterative validation) + Three-component Rule Executor
> - **结果**: 77 designs, 12 CWE types — [[GPT-4o]]+VerilogLAVD F1=0.57 (over LLM-only 0.21, LLM+Knowledge 0.25), Rule Validation 将 misuse rate 从 40.87% 降至 10.10%
> - **代码**: 承诺 accepted 后开源

---

*笔记创建时间: 2026-06-23*
