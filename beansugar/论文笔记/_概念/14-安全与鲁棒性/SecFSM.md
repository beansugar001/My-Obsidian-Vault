---
type: concept
aliases: [SecFSM框架]
---

# SecFSM

## 定义
Security-aware FSM code generation framework，基于 LLM + 知识图谱的 Verilog FSM 安全代码自动生成框架。

## 核心要点
1. 两阶段流程：Structure-aware FSM Graph Analysis → Knowledge-guided Vulnerability Confirmation
2. 构建 FSKG（FSM Security Knowledge Graph）组织漏洞、语义解释和修复模式
3. Model-agnostic：支持 GPT-4o、Claude 3.5、DeepSeek-R1
4. DeepSeek-R1 达到 48/52 安全通过率，比 Base（19/52）提升显著

## 代表工作
- [[SecFSM]]（自身）

## 相关概念
- [[FSKG]]
- [[RAG]]
- [[AutoGen]]
- [[Cypher]]
