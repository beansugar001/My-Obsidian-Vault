---
type: concept
aliases: [Large Language Model, 大语言模型]
---

# LLM

## 定义
基于 Transformer 架构的大规模语言模型，通过海量文本预训练获得通用语言理解和生成能力。

## 核心要点
1. 在硬件设计领域，LLM 被用于 Verilog 代码生成、调试、优化等任务
2. 训练数据中 Verilog 代码占比不足 0.04%，导致 FSM 安全知识严重不足
3. SecFSM 通过外部知识图谱补偿 LLM 的领域安全知识缺失

## 代表工作
- [[SecFSM]]: 知识图谱引导的安全 Verilog FSM 生成

## 相关概念
- [[GPT-4o]]
- [[DeepSeek-R1]]
- [[RAG]]
