---
type: concept
aliases: [Cohen's $\kappa$, Cohen's Kappa Coefficient]
---

# Cohen's Kappa

## 定义
评估两位标注者之间一致性的统计指标，排除随机一致。$\kappa = \frac{p_o - p_e}{1 - p_e}$，其中 $p_o$ 为观察到的一致性比例，$p_e$ 为随机一致概率。

## 核心要点
1. SecFSM 实验中用于验证安全标注可靠性
2. 总体 $\kappa = 0.974$（优秀一致性）
3. 分方法: Base $\kappa = 1.000$, RAG $\kappa = 0.985$, SecFSM $\kappa = 0.879$

## 代表工作
- [[SecFSM]]: 验证两位安全标注员的标注一致性

## 相关概念
- [[SecFSM]]
