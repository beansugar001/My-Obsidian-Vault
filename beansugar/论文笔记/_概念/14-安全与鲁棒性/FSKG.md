---
type: concept
aliases: [FSM Security Knowledge Graph]
---

# FSKG

## 定义
FSM Security Knowledge Graph，面向 FSM 硬件安全的知识图谱，组织漏洞类型（CWE）、语义解释和修复模式，为 LLM 提供领域安全知识。

## 核心要点
1. 手工构建，采用 top-down ontology + manual cleaning + entity alignment
2. 覆盖 Dead State、Hamming Distance、FIF-metics 等 FSM 特有漏洞
3. 通过 Cypher 查询语句进行知识检索
4. 规模有限但 FSM 安全漏洞类型本身有限且变化慢

## 代表工作
- [[SecFSM]]: 核心组件，提供两阶段漏洞分析的知识基础

## 相关概念
- [[SecFSM]]
- [[Cypher]]
- [[CWE]]
