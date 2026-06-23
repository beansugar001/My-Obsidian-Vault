---
type: concept
aliases: [Knowledge Graph, 知识图谱]
---

# Knowledge Graph

## 定义
以图结构（节点+边）组织知识的数据模型，节点表示实体，边表示关系。

## 核心要点
1. 在 SecFSM 中用于补偿 LLM 训练数据中缺失的 FSM 安全知识
2. FSKG 采用三层语义架构：漏洞 → 语义 → 缓解方案
3. 使用 Cypher 查询语言进行知识检索

## 代表工作
- [[SecFSM]]: 基于 FSKG 的两阶段漏洞分析与安全生成

## 相关概念
- [[FSKG]]
- [[Cypher]]
