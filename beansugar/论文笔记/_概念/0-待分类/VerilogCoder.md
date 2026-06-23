---
type: concept
aliases: [Verilog代码生成器]
---

# VerilogCoder

## 定义
基于多智能体协作的 Verilog 代码生成系统，结合图规划与 AST 波形追踪迭代生成、仿真、调试。

## 核心要点
1. 使用 graph-based planning + AST waveform tracing
2. 多轮迭代相比单次生成显著提升功能正确性
3. 在 SecFSM 中被列为对比相关工作

## 代表工作
- [[SecFSM]]: 相关工作，但未专注于 FSM 安全约束

## 相关概念
- [[RTLCoder]]
- [[SecFSM]]
