---
type: concept
aliases: [硬件描述语言]
---

# Verilog

## 定义
硬件描述语言（HDL），用于 RTL 级数字电路设计。FSM 通常以 Verilog 实现。

## 核心要点
1. 在主流 LLM 训练数据中占比不足 0.04%，安全知识极其稀疏
2. 代码合成到 SoC 后无法修补，安全性要求极高
3. 功能正确 ≠ 安全（如加法器通过所有测试但仍可能含 CWE-190 溢出漏洞）

## 代表工作
- [[SecFSM]]: 安全 Verilog FSM 代码生成
- [[VerilogCoder]]: 自主 Verilog 编码代理
- [[RTLCoder]]: 轻量 RTL 代码生成

## 相关概念
- [[FSM]]
- [[SoC]]
- [[VerilogEval]]
