---
type: concept
aliases: [硬件木马]
---

# Hardware Trojan

## 定义
恶意篡改的电路修改，可隐藏在 FSM 的 unreachable states 中休眠，直至特定条件触发导致系统异常或信息泄露。

## 核心要点
1. FSM 中 unreachable states 为 Hardware Trojan 提供插入机会
2. Damage: DoS, 特权提升, 数据泄露
3. SecFSM 通过检测 Dead State 间接防御 Hardware Trojan 插入

## 代表工作
- [[SecFSM]]: Stage I 检测 unreachable states

## 相关概念
- [[FSM]]
- [[CWE-1245]]
