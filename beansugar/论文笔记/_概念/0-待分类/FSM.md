---
type: concept
aliases: [Finite State Machine, 有限状态机]
---

# FSM

## 定义
Finite State Machine，有限状态机，可形式化为 6 元组 $(S, I, O, s_0, \Omega, \gamma)$，是 SoC 控制逻辑的核心组件。

## 数学形式
$$\text{FSM} = (S, I, O, s_0, \Omega, \gamma)$$

其中 $\Omega: S \times I \rightarrow S$ 为状态转换函数，$\gamma$ 为输出函数。

## 核心要点
1. 分为 Reset Logic、State Transition Logic、State Output Logic 三部分
2. FSM 若状态数少于寄存器容量则为 incomplete FSM，存在 don't-care states
3. Protected State 指安全关键状态，需特殊处理
4. Mealy FSM: $\gamma: S \times I \rightarrow O$，Moore FSM: $\gamma: S \rightarrow O$

## 代表工作
- [[SecFSM]]: 知识图谱引导的安全 Verilog FSM 生成

## 相关概念
- [[CWE-1245]]
- [[SoC]]
- [[Verilog]]
- [[State Transition Graph]]
