---
type: concept
aliases: [TinyRAG]
---

# TinyRAG

## 定义
轻量级 RAG 实现框架，SecFSM 实验中用作 RAG 基线。

## 核心要点
1. 检索参数: top-k=1, chunk 600 tokens, overlap 150 tokens
2. 将检索到的 top-1 安全知识 chunk 以标准上下文增强方式追加到用户需求后
3. 不做结构化、过滤或重新表述

## 代表工作
- [[SecFSM]]: 作为 RAG 基线实现

## 相关概念
- [[RAG]]
- [[LLM]]
