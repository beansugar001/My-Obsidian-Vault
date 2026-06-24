---
type: concept
aliases: [Control Flow Graph, 控制流图, 控制流程图]
---

# CFG

## 定义
Control Flow Graph（控制流图）用有向图表示程序可能经过的执行路径。节点通常表示语句或基本块，边表示控制可从一个节点转移到另一个节点的可能性。

## 在 Verilog 中
对于下面的时序逻辑：

```verilog
always @(posedge clk) begin
    if (enable)
        q <= d;
    else
        q <= 0;
end
```

对应的控制流可概括为：

```text
Always -> If
If -[true]-> q <= d
If -[false]-> q <= 0
```

这里的 true 与 false 边表示 `enable` 条件的两种取值。CFG 关注“可能走哪条分支”，而不是 `d` 的数值从哪里来。

## 核心要点
1. `if/else` 产生条件分支；`case` 产生多个选择分支；`for` 会形成初始化、条件判断、循环体和迭代更新的路径。
2. 对时钟触发的 `always @(posedge clk)`，CFG 表示一次触发时块内语句的控制结构，不等同于完整的硬件时序模型。
3. CFG 常用于检查不可达语句、异常控制路径，以及安全检查是否能在敏感操作前被绕过。
4. CFG 的边表达控制依赖；变量之间的取值依赖应由 [[DDG]] 表达。

## 在 VerilogLAVD 中
[[VerilogLAVD]] 在 AST 图的基础上额外创建 `CFG` 边。`if` 的两个分支会标记为 `condition: true` 与 `condition: false`；`for` 循环会连接初始化、循环体、更新语句和循环头，从而表示可能的循环路径。

## 相关概念
- [[AST]]
- [[DDG]]
- [[Verilog]]
- [[Cypher]]