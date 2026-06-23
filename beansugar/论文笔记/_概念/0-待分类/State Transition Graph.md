---
type: concept
aliases: [STG, 状态转换图]
---

# State Transition Graph

## 定义
FSM 的有向图表示，顶点为状态 $S$，边为状态转换 $t = T(S_i, S_j)$。

## 数学形式
$$G_{ST} = (S, E)$$

每条边对应一个状态转换 triple $(s_i, e, s_j)$。

## 核心要点
1. 是 SecFSM Stage I 结构化分析的核心数据结构
2. 通过特征向量 $F(s_i, e, s_j)$ 或部分特征 $F'(s_i, e, s_j)$ 匹配漏洞规则
3. 带有安全语义（protected states, transition conditions, outputs）

## 代表工作
- [[SecFSM]]: 构建安全语义 STG 进行两阶段漏洞分析

## 相关概念
- [[FSM]]
- [[FSKG]]
