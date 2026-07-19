---
title: "WorldMM: Dynamic Multimodal Memory Agent for Long Video Reasoning"
method_name: "WorldMM"
authors: [Woongyeong Yeo, Kangsan Kim, Jaehong Yoon, Sung Ju Hwang]
year: 2025
venue: arXiv
tags: [long-video-reasoning, multimodal-memory, video-question-answering, retrieval-agent, memory-agent]
zotero_collection: ""
image_source: arxiv-html-and-caption-summary
arxiv: "2512.02425"
arxiv_html: "https://arxiv.org/html/2512.02425"
project_page: "https://worldmm.github.io"
created: 2026-07-19
---

# 论文笔记：WorldMM: Dynamic Multimodal Memory Agent for Long Video Reasoning

## 元信息

| 项目 | 内容 |
|------|------|
| 方法名 | WorldMM |
| 标题 | WorldMM: Dynamic Multimodal Memory Agent for Long Video Reasoning |
| 作者 | Woongyeong Yeo, Kangsan Kim, Jaehong Yoon, Sung Ju Hwang |
| 机构 | KAIST |
| 论文 | [arXiv:2512.02425](https://arxiv.org/abs/2512.02425) |
| 项目主页 | [worldmm.github.io](https://worldmm.github.io) |
| 任务 | 长视频问答、长视频推理、egocentric video reasoning |
| 主要基线 | [[M3-Agent]], [[EgoRAG]], [[HippoMM]], [[Video-RAG]], [[GPT-5]], [[Gemini 2.5 Pro]], [[Qwen3-VL]] |

---

## 一句话总结

> WorldMM 用 episodic、semantic、visual 三类记忆和一个多轮检索 agent，让长视频推理从“塞进上下文”变成“按问题动态查记忆”。

---

## 核心贡献

1. **多模态多尺度记忆系统**：构建 [[Episodic Memory]]、[[Semantic Memory]] 和 [[Visual Memory]] 三种互补记忆，分别覆盖事件、长期知识和视觉细节。
2. **动态检索 agent**：不是固定检索若干片段，而是让 agent 多轮决定检索哪种记忆、用什么查询、是否继续检索。
3. **长视频高效推理**：避免把超长视频帧直接塞进 [[Video LLM]] 上下文，通过检索相关记忆降低推理成本。
4. **跨基准验证**：在 EgoLifeQA、Ego-R1 Bench、HippoVlog、LVBench、Video-MME (L) 五个 benchmark 上取得平均 69.5，超过最强 baseline 8.4 个百分点。

---

## 问题背景

### 要解决的问题

长视频，尤其是 day-long 或 week-long egocentric video，远超当前 [[Video LLM]] 的上下文窗口。即使低帧率采样，1 fps 的一天视频也会产生海量帧。直接输入全视频既昂贵，也容易被无关帧干扰。

### 现有方法的局限

1. **固定采样或固定片段检索太僵硬**：很多方法固定取若干 30 秒片段，不能根据问题动态改变时间尺度。
2. **只用文本记忆会丢视觉细节**：caption 可以压缩视频，但对象、动作、场景布局等细粒度视觉信息不一定能被文本完整表示。
3. **只用视觉检索缺少长期抽象知识**：长期习惯、人物关系、偏好等信息更适合用结构化语义记忆保存。
4. **单轮检索容易不够**：复杂问题可能需要先查事件，再查视觉证据，再查长期语义知识，多轮修正比一次检索更稳。

### 本文动机

作者认为长视频推理需要像人一样维护多种记忆：事件记忆记录发生过什么，语义记忆记录长期关系和习惯，视觉记忆保留原始视觉证据。问题来了以后，agent 应该根据问题动态选择查哪类记忆，而不是预设单一路径。

---

## 方法详解

### 总体架构

WorldMM 由三个阶段组成：

1. **Multimodal Memory Construction**
   - 从长视频流构建 episodic、semantic、visual 三类记忆。
   - episodic memory 以多时间尺度 knowledge graph 表示事件。
   - semantic memory 增量维护实体关系、习惯、偏好等长期知识。
   - visual memory 保存帧级或片段级视觉表示，支持视觉细节检索。

2. **Adaptive Memory Retrieval**
   - 检索 agent 根据问题和已有检索历史，多轮决定下一步查哪类记忆。
   - 可选择 episodic、semantic、visual memory，也可以判断信息已足够并停止。

3. **Response Generation**
   - response agent 读取问题、检索到的记忆和推理历史，生成 grounded answer。

### 核心模块

#### 模块1：[[Episodic Memory|Episodic Memory Construction]]

**设计动机**：长视频中的问题经常涉及“某个时间段发生了什么”。因此需要把视频事件组织成可检索的时间结构。

**具体实现**：
- 对视频按多个时间尺度切段，例如短、中、长时间窗口。
- 每个 segment 由 video LLM 生成 caption。
- caption 再被抽取为事件 triplets，构成不同时间尺度的 knowledge graph。
- 多尺度结构让 agent 可以从粗到细检索：先定位大致时间，再查更细事件。

#### 模块2：[[Semantic Memory|Semantic Memory Construction]]

**设计动机**：某些问题不是单个事件能回答的，而是依赖长期模式，例如“我通常和谁吃午饭”“我习惯用什么擦厨房用品”。

**具体实现**：
- 将粗粒度视频片段转成 semantic triplets。
- 关注实体关系、偏好、习惯、能力、概念知识等长期信息。
- 新 triplets 会与已有 semantic memory consolidation，去重、合并或解决冲突。
- 最终形成不断演化的长期知识库。

#### 模块3：[[Visual Memory|Visual Memory Construction]]

**设计动机**：文本 caption 不一定能保存全部视觉细节。比如“烤的到底是红薯还是面包”，需要看图像细节。

**具体实现**：
- 构建 feature-based visual memory：保存视觉 embedding，支持基于查询的相似检索。
- 构建 timestamp-based visual memory：保存特定时间戳帧，支持按时间直接取回视觉证据。
- 两种模式互补：前者适合找相似场景，后者适合根据 episodic memory 定位后看对应画面。

#### 模块4：[[Retrieval Agent|Adaptive Retrieval Agent]]

**设计动机**：不同问题需要不同记忆组合。固定检索策略会浪费上下文或错过关键信息。

**具体实现**：
- 输入问题、历史检索结果和当前推理状态。
- 每一轮输出一个动作：选择 memory type `m` 和 query `q`，或停止检索。
- episodic memory 支持多时间尺度检索。
- semantic memory 支持实体/关系/习惯查询。
- visual memory 支持 feature-based 或 timestamp-based 检索。
- 最多运行若干轮，信息足够后交给 response agent。

#### 模块5：[[Response Agent|Response Generation]]

**设计动机**：检索到的信息可能来自不同模态和不同时间尺度，需要整合成最终答案。

**具体实现**：
- 使用检索内容、问题和多轮推理历史生成回答。
- 强调 grounded response：答案必须基于检索证据，不凭空猜测。

---

## 关键公式

### 公式1：[[Multiscale Episodic Memory|多时间尺度集合]]

$$
T = \{t_1, t_2, \ldots, t_n\}, \quad t_1 < t_2 < \cdots < t_n
$$

**含义**：WorldMM 使用多个时间尺度构建 episodic memory，而不是只使用固定窗口。

**符号说明**：
- $T$：时间尺度集合。
- $t_i$：第 $i$ 个时间尺度。

### 公式2：[[Episodic Knowledge Graph|Episodic Memory 表示]]

$$
M_E = \{G_{t_1}, G_{t_2}, \ldots, G_{t_n}\}
$$

**含义**：每个时间尺度对应一个事件 knowledge graph，多尺度图共同构成 episodic memory。

**符号说明**：
- $M_E$：episodic memory。
- $G_{t_i}$：时间尺度 $t_i$ 下的事件图。

### 公式3：[[Semantic Memory Consolidation|语义记忆合并]]

$$
\operatorname{Consolidate}(G^k, T^{k+1})
= (G^k \setminus T_{\operatorname{pop}}) \cup T_{\operatorname{new}}
$$

**含义**：新语义 triplets 到来后，系统移除冗余或冲突旧知识，并加入更新后的新知识。

**符号说明**：
- $G^k$：当前语义记忆图。
- $T^{k+1}$：新抽取的语义 triplets。
- $T_{\operatorname{pop}}$：应删除或合并的旧 triplets。
- $T_{\operatorname{new}}$：更新后的 triplets。

### 公式4：[[Visual Memory|Feature-based Visual Memory]]

$$
M_V^f = \{f_1^v, f_2^v, \ldots, f_L^v\}
$$

**含义**：视觉记忆保存帧或片段的视觉 embedding，用于相似度检索。

**符号说明**：
- $M_V^f$：feature-based visual memory。
- $f_i^v$：第 $i$ 个视觉 embedding。
- $L$：视觉条目数量。

### 公式5：[[Timestamp Visual Memory|Timestamp-based Visual Memory]]

$$
M_V^I = \{(t, I_t)\mid I_t = V(t),\ t \in [0, \operatorname{len}(V)]\}
$$

**含义**：系统也保存时间戳到视觉帧的映射，方便根据事件时间直接取回原始视觉证据。

**符号说明**：
- $M_V^I$：timestamp-based visual memory。
- $I_t$：时间 $t$ 的视频帧。
- $V(t)$：视频在时间 $t$ 的帧访问函数。

### 公式6：[[Retrieval Policy|检索 agent 决策]]

$$
R(q, r_{<i}) =
\begin{cases}
(m_i, q_i), & \text{if } r_{<i}\ \text{is insufficient and } i \le N, \\
\operatorname{STOP}, & \text{otherwise}.
\end{cases}
$$

**含义**：检索 agent 根据问题和已有检索历史决定继续查哪种记忆，或停止检索。

**符号说明**：
- $q$：用户问题。
- $r_{<i}$：第 $i$ 轮之前的检索历史。
- $m_i$：第 $i$ 轮选择的记忆类型。
- $q_i$：第 $i$ 轮检索 query。
- $N$：最大检索轮数。

---

## 关键图表

### Figure 1: Concept Figure / 概念图

[Figure 1 source](https://arxiv.org/html/2512.02425)

**说明**：对比一天长视频直接输入、M3-Agent、EgoRAG 和 WorldMM。核心信息是：WorldMM 不固定使用单一记忆或固定片段，而是构建多种记忆并动态选择。

### Figure 2: Overview of WorldMM / 方法总览

[Figure 2 source](https://arxiv.org/html/2512.02425)

**说明**：展示三阶段 pipeline：左侧构建 episodic/semantic/visual memory，中间 retrieval agent 多轮检索，右侧 response agent 生成答案。

### Figure 3: Memory Type Utilization / 不同任务类别的记忆使用比例

**说明**：在 EgoLifeQA 的不同类别中，WorldMM 使用的记忆类型比例不同。HabitInsight 和 RelationMap 更多依赖 semantic memory，EntityLog 和 EventRecall 更多受益于 visual memory，说明检索 agent 确实会按问题类型动态选记忆。

### Figure 4: Qualitative Results / 定性案例

**说明**：案例 (a) 表明仅靠 episodic memory 难以识别烘焙物品，visual memory 能补足视觉细节；案例 (b) 表明 episodic memory 难以捕捉长期习惯，semantic memory 能提供“常用厨房湿巾”等长期知识。

### Figure 5: Average tIoU and Performance / 时序定位与准确率关系

**说明**：WorldMM 的平均 tIoU 明显高于 baselines，并且 tIoU 与最终准确率正相关，说明更好的时间段定位能提升长视频推理。

### Figure 6: Average Latency and Performance / 延迟-性能关系

**说明**：WorldMM 在低延迟下保持更高准确率。直接长视频 LLM 推理延迟更高且表现较低；WorldMM 只检索相关片段，因此更高效。

### Figure 7: Retrieval Steps / 最大检索轮数影响

**说明**：随着最大检索轮数增加，WorldMM 在多个 benchmark 上准确率持续提升。EgoLifeQA 上五轮检索相比单轮有 9.3% 提升，说明多轮修正检索很重要。

### Figure 8: HippoVlog Memory Utilization / HippoVlog 类别记忆使用

**说明**：不同 HippoVlog 类别触发不同记忆组合，Visual 类更依赖 visual memory，Summarization 类更依赖 episodic memory。

### Figure 9: Video Caption Prompt

**说明**：附录给出视频 caption 生成提示词，要求结构清晰、保留关键信息、表达简洁、严格遵循事实。

### Figure 10: Named Entity Recognition Prompt

**说明**：用于从 caption 中识别实体，为 episodic triplet extraction 提供实体候选。

### Figure 11: Episodic Triplet Extraction Prompt

**说明**：用于把视频 caption 转换为事件 triplets，服务于 episodic knowledge graph。

### Figure 12: Episodic Memory Construction Prompt

**说明**：用于把更细粒度 caption 合成为更粗时间尺度 caption，从而构建多尺度 episodic memory。

### Figure 13: Episodic Memory Retrieval Prompt

**说明**：用于在多个时间尺度 caption 中选择与问题最相关的片段。

### Figure 14: Semantic Triplet Extraction Prompt

**说明**：用于抽取长期关系、属性偏好、习惯能力和概念知识等 semantic triplets。

### Figure 15: Semantic Memory Consolidation Prompt

**说明**：用于合并相似知识、解决冲突并保留唯一信息。

### Figure 16: Retrieval Agent Prompt

**说明**：定义 retrieval agent 如何根据问题和历史检索结果选择 episodic、semantic、visual 记忆或停止。

### Figure 17: Response Agent Prompt

**说明**：定义最终回答生成 agent 如何基于检索证据和推理历史生成答案。

---

## 关键表格

### Table 1: Main Results / 五个长视频 QA benchmark 主结果

| Model | EgoLifeQA | Ego-R1 Bench | HippoVlog | LVBench | Video-MME (L) | Avg. |
|-------|-----------|--------------|-----------|---------|---------------|------|
| Qwen3-VL-8B | 38.6 | 35.7 | 74.4 | 48.3 | 61.0 | 51.6 |
| Gemini 2.5 Pro | 46.4 | 46.7 | 72.0 | 57.0 | 55.7 | 55.6 |
| GPT-5 | 48.6 | 46.3 | 75.7 | 60.4 | 74.3 | 61.1 |
| VideoChat-Flash | 34.2 | 42.7 | 58.0 | 33.2 | 44.1 | 42.4 |
| Time-R1 | 48.8 | 48.0 | 54.6 | 31.1 | 37.6 | 44.0 |
| Video-RTS | 48.2 | 47.4 | 59.0 | 39.8 | 47.9 | 48.6 |
| LightRAG | 48.8 | 52.3 | 47.4 | 30.4 | 46.6 | 45.1 |
| HippoRAG | 59.6 | 56.0 | 63.2 | 54.0 | 52.1 | 57.0 |
| Video-RAG | 55.4 | 49.7 | 65.1 | 33.1 | 55.4 | 51.7 |
| EgoRAG | 52.0 | 49.0 | 57.5 | 32.2 | 41.1 | 46.4 |
| Ego-R1 | 53.0 | 52.0 | 58.8 | 34.1 | 42.7 | 48.1 |
| HippoMM | 54.6 | 53.0 | 71.9 | 38.2 | 41.6 | 51.8 |
| M3-Agent | 53.5 | 52.0 | 65.5 | 49.3 | 55.3 | 55.1 |
| WorldMM-8B | 56.4 | 52.0 | 69.7 | 55.4 | 66.0 | 59.9 |
| **WorldMM-GPT** | **65.6** | **65.3** | **78.3** | **61.9** | **76.6** | **69.5** |

**关键发现**：WorldMM-GPT 平均 69.5，比最强 baseline GPT-5 的 61.1 高 8.4 个百分点；WorldMM-8B 也高于 Qwen3-VL-8B。

### Table 2: Memory Type Ablation / 不同记忆组合

| Memory | EgoLifeQA Avg. | Ego-R1 Avg. | HippoVlog Avg. | LVBench | Video-MME (L) | Avg. |
|--------|----------------|-------------|----------------|---------|---------------|------|
| E | 62.6 | 57.0 | 73.6 | 60.6 | 72.7 | 64.9 |
| V | 37.2 | 34.2 | 51.3 | 47.4 | 64.2 | 44.9 |
| E+S | 63.4 | 61.0 | 73.8 | 58.8 | 74.1 | 66.8 |
| E+V | 63.3 | 63.0 | 75.2 | 59.8 | 76.0 | 66.9 |
| **E+S+V** | **65.6** | **65.3** | **78.3** | **61.9** | **76.6** | **69.5** |

**关键发现**：三类记忆合用最好。Episodic memory 是基础，visual memory 补视觉细节，semantic memory 补长期关系和习惯。

### Table 3: Temporal Grounding / 平均 tIoU

| Model | EgoLifeQA | Ego-R1 Bench | LVBench |
|-------|-----------|--------------|---------|
| Time-R1 | 0.58 | 0.59 | 2.70 |
| Qwen3 Emb. | 4.35 | 2.87 | 4.54 |
| HippoRAG | 4.00 | 3.28 | 4.30 |
| InternVideo2 | 3.36 | 2.60 | 3.55 |
| EgoRAG | 3.60 | 2.73 | 3.50 |
| Ego-R1 | 3.70 | 2.89 | 3.60 |
| AKS | 2.75 | 2.30 | 3.52 |
| **WorldMM** | **10.09** | **9.17** | **9.57** |

**关键发现**：WorldMM 在时间定位上大幅领先，支持“动态时间尺度检索”是有效的。

### Table 4: Module Variants / 模块消融

| Variant | EgoLifeQA Avg. | LVBench Acc. |
|---------|----------------|--------------|
| Fixed Timescale | 51.8 | 47.9 |
| Embedding Retrieval | 52.0 | 50.9 |
| w/o Semantic Consolidation | 53.0 | 54.2 |
| Visual Feature Retrieval only | 53.6 | 52.4 |
| Visual Timestamp Retrieval only | 51.8 | 52.9 |
| **WorldMM** | **56.4** | **55.4** |

**关键发现**：多尺度 episodic graph、semantic consolidation、visual dual-mode retrieval 都贡献有效。

### Table 5: Dataset Summary

**说明**：汇总 EgoLifeQA、Ego-R1 Bench、HippoVlog、LVBench、Video-MME (L) 的视频来源、时长、问题类型和评估指标。它证明实验覆盖 egocentric day-long reasoning、long-horizon QA、visual/audio/summary 等多类需求。

### Table 6: EgoLifeQA Query Categories

**说明**：定义 EgoLifeQA 的 EntityLog、EventRecall、HabitInsight、RelationMap、TaskMaster 等类别。不同类别对应不同记忆需求：事件类偏 episodic，习惯/关系类偏 semantic，实体/场景类更需要 visual。

### Table 7: Category-wise Performance on Four Benchmarks

**说明**：给出 EgoLifeQA、Ego-R1、HippoVlog、LVBench 的细分类结果。WorldMM-GPT 在大多数类别上最好，尤其是需要视觉细节或长期关系的类别。

### Table 8: Video-MME (L) Category-wise Performance

**说明**：在 Video-MME 长视频子集上，WorldMM-GPT 平均 76.6，WorldMM-8B 平均 66.0；WorldMM 对不同题型保持稳定优势。

### Table 9: Category-wise tIoU

**说明**：WorldMM 在 EgoLifeQA、Ego-R1 和 LVBench 各类别上的 tIoU 均明显高于检索 baselines，说明它不仅答得好，也更能定位正确视频片段。

### Table 10: Dynamic Temporal Scope Retrieval Baseline Comparison

**说明**：与动态时间范围检索 baselines 的分类表现比较，WorldMM 在多类任务上保持更高准确率，说明多模态记忆和 retrieval agent 不是只优化定位指标，也提升最终 QA。

### Table 11: Backbone Robustness

| Variant | EgoLifeQA | LVBench | Video-MME (L) |
|---------|-----------|---------|---------------|
| WorldMM-Gemini + Qwen3-VL-Emb | 67.4 | 61.5 | 74.9 |
| WorldMM-Gemini + VLM2Vec-V2 | 68.2 | 61.7 | 75.8 |
| WorldMM-GPT + Qwen3-VL-Emb | 66.0 | 61.4 | 75.8 |
| WorldMM-GPT + VLM2Vec-V2 | 65.6 | 61.9 | 76.6 |

**关键发现**：WorldMM 对不同 LLM 和 embedding backbone 较稳健。

### Table 12: Episodic Timescale Sensitivity

**说明**：测试不同 episodic timescale 配置。结论是多尺度设计提升整体性能，但 WorldMM 对具体时间尺度取值并不过度敏感。

### Table 13: Episodic Triplet Extraction Example

**说明**：展示 caption 如何被转成事件 triplets，用于 episodic knowledge graph。

### Table 14: Semantic Triplet Extraction Example

**说明**：展示从视频上下文中抽取长期语义 triplets，例如人物关系、习惯、偏好。

### Table 15: Semantic Consolidation Example

**说明**：展示新旧 semantic triplets 如何合并、去重或解决冲突。

### Table 16: Multi-turn Refinement Example

**说明**：展示 retrieval agent 如何通过多轮检索修正初始检索不足，逐步获取更相关证据。

---

## 实验

### 数据集

| 数据集 | 特点 | 用途 |
|--------|------|------|
| EgoLifeQA | egocentric life videos，多类别长时记忆问题 | 主评测 |
| Ego-R1 Bench | egocentric long video reasoning | 主评测 |
| HippoVlog | vlog 场景，含 audio/visual/summary 类别 | 多模态评测 |
| LVBench | long video benchmark | 通用长视频评测 |
| Video-MME (L) | Video-MME 长视频子集 | 长视频多模态评测 |

### Baselines

| 类别 | 方法 |
|------|------|
| Base Models | Qwen3-VL-8B, Gemini 2.5 Pro, GPT-5 |
| Long Video LLMs | VideoChat-Flash, Time-R1, Video-RTS |
| RAG-based Video LLMs | LightRAG, HippoRAG, Video-RAG |
| Memory-based Video LLMs | EgoRAG, Ego-R1, HippoMM, M3-Agent |

### 实现细节

- 主要报告 WorldMM-GPT 和 WorldMM-8B。
- 使用 GPT-5-mini 构建 memory。
- 使用 GPT-5 或 Qwen3-VL-8B 作为 response / reasoning backbone。
- visual memory retrieval 使用 multimodal embedding model，例如 VLM2Vec-V2 或 Qwen3-VL-Emb。
- episodic memory 使用多个时间尺度，例如 30 秒、3 分钟、10 分钟、1 小时。
- Video-MME (L) 中采样 0.5 fps，并受 768 frames context limit 限制。

### 主要结果

1. **主结果**：WorldMM-GPT 平均 69.5，超过最强 baseline 8.4。
2. **记忆组合**：E+S+V 平均 69.5，高于 E+S 66.8 和 E+V 66.9。
3. **视觉记忆价值**：E+S+V 相比 E+S 平均提升约 4.2，视觉信息能补足 caption 遗漏的物体和动作细节。
4. **语义记忆价值**：HabitInsight 中 full memory 达到 76.9，相比 E+V 提升 23，说明长期习惯/关系知识很关键。
5. **时间定位**：WorldMM 的平均 tIoU 在三个 benchmark 上均约 9-10，显著高于 baselines。
6. **多轮检索**：最大五轮检索比单轮在 EgoLifeQA 上提升 9.3。
7. **效率**：WorldMM 的延迟-准确率 trade-off 优于直接长视频 LLM 和常规 RAG/memory 方法。

---

## 批判性思考

### 优点

1. **问题切得准**：长视频推理的瓶颈不只是上下文长度，还有记忆类型和检索策略不匹配。
2. **三类记忆互补清晰**：episodic 负责事件，semantic 负责长期关系，visual 负责视觉细节，分工自然。
3. **动态检索比固定检索更合理**：agent 可以按问题类型和检索历史调整策略，多轮检索尤其适合复杂问答。
4. **实验覆盖较广**：五个 benchmark、多个 baseline、memory ablation、retrieval steps、latency、backbone robustness 都有验证。
5. **可解释性较好**：使用知识图、triplets 和检索轨迹，能看到模型为什么查某类记忆。

### 局限性

1. **离线预处理成本高**：caption、triplet extraction、semantic consolidation 都需要额外 LLM 调用。
2. **依赖上游 caption 和 triplet 质量**：如果视频 caption 漏掉细节，episodic/semantic memory 会继承错误。
3. **实时更新能力有限**：作者讨论中承认当前更适合离线或准离线场景，实时长视频流更新仍有挑战。
4. **Prompt-heavy 系统复杂**：附录 Figure 9-17 显示大量组件依赖 prompt，跨模型迁移时可能要重新调。
5. **隐私和安全问题未深入处理**：长期生活视频记忆包含大量个人信息，论文主要关注推理性能，没有系统讨论隐私保护机制。

### 潜在改进方向

1. 用更轻量的 video captioner 和 triplet extractor 降低 memory construction 成本。
2. 引入 memory confidence 或 provenance，标记每条记忆来自哪些帧、可信度如何。
3. 支持在线增量更新，让 semantic memory 可随视频流实时演化。
4. 增加隐私过滤或本地化记忆策略，避免长期个人记忆泄露。
5. 对 retrieval agent 做更严格的失败分析，例如何时过度依赖 semantic memory、何时漏查 visual memory。

### 可复现性评估

- [x] 项目主页提供。
- [x] arXiv 论文和 prompt 附录完整。
- [x] 数据集和 benchmark 描述较详细。
- [x] 关键模块、表格、消融和参数给出较多。
- [ ] 代码是否完整开源需进一步确认项目页。
- [ ] 记忆构建成本、token/call 成本可以更透明。

---

## 关联笔记

### 基于

- [[Retrieval-Augmented Generation]]：WorldMM 本质上是面向长视频的多模态 RAG / memory agent。
- [[Knowledge Graph]]：episodic 和 semantic memory 都以 triplets / graph 形式组织。
- [[Video Question Answering]]：核心任务是长视频 QA。
- [[Long Context Video Understanding]]：WorldMM 通过外部记忆绕开上下文限制。

### 对比

- [[M3-Agent]]：使用多模态 memory，但 WorldMM 强调动态选择记忆类型和时间尺度。
- [[EgoRAG]]：更偏 fixed/hierarchical retrieval，WorldMM 引入 visual memory 和 retrieval agent。
- [[HippoMM]]：同为 memory-based video method，WorldMM 在多 benchmark 上平均更高。

### 方法相关

- [[Episodic Memory]]：多时间尺度事件图。
- [[Semantic Memory]]：长期关系、习惯和偏好知识。
- [[Visual Memory]]：视觉 embedding 与 timestamp frame 访问。
- [[Retrieval Agent]]：多轮工具式记忆检索。
- [[Response Agent]]：基于检索证据生成答案。

---

## 速查卡片

> [!summary] WorldMM
> - **核心**：长视频推理不直接塞全视频，而是构建多模态多尺度记忆并动态检索。
> - **方法**：episodic memory + semantic memory + visual memory + retrieval agent + response agent。
> - **结果**：五个 benchmark 平均 69.5，比最强 baseline 高 8.4；E+S+V 组合最好。
> - **亮点**：多轮检索、动态记忆类型选择、视觉与语义互补。
> - **风险**：离线构建成本高，依赖 caption/triplet 质量，实时更新和隐私保护仍不足。

---

## 自检

- [x] 已覆盖 Figure 1-17 的题注和作用。
- [x] 已覆盖 Table 1-16，主表保留关键数值，附录表保留作用和结论。
- [x] 已列出论文中的核心公式 1-6，并补充含义与符号说明。
- [x] 已包含实验设置、指标、baselines、主结果和消融结论。
- [x] 已给出批判性分析、局限性和潜在改进方向。

---

*笔记创建时间: 2026-07-19*
