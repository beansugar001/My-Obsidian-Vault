---
type: concept
aliases: [Common Weakness Enumeration, 通用弱点枚举]
---

# CWE

## 定义
Common Weakness Enumeration，由 MITRE 维护的软硬件安全弱点分类体系，是 FSKG 的主要知识来源。

## 核心要点
1. CWE-1245 (Improper FSM in Hardware Logic): 缺失 default 语句导致 unreachable states
2. CWE-190 (Integer Overflow): 算术运算溢出
3. 消除 CWE-1245 可降低约 43% 的系统漏洞

## 代表工作
- [[SecFSM]]: 基于 CWE 构建 FSKG，覆盖 FSM 特有漏洞

## 相关概念
- [[FSKG]]
- [[CWE-1245]]
- [[CWE-190]]
