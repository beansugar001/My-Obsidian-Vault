---
type: concept
aliases: [检索增强生成, Retrieval-Augmented Generation]
---

# RAG

## 定义
Retrieval-Augmented Generation，在 LLM 生成前从外部知识库检索相关信息注入 prompt，增强生成质量与事实性。

## 核心要点
1. 解耦知识存储与模型推理，知识库可独立更新
2. 减少 LLM 幻觉，提升领域专业性
3. 在硬件安全领域，RAG 的粗粒度检索不足以覆盖细粒度安全约束

## 代表工作
- [[SecFSM]]: 对比了 RAG 基线，发现其安全增强有限（GPT-4o 从 3 提升到 16/52）

## 相关概念
- [[FSKG]]
- [[SecFSM]]
