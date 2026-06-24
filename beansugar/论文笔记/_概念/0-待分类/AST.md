---
type: concept
aliases: [Abstract Syntax Tree, 抽象语法树, AST图]
---

# AST

## 定义
Abstract Syntax Tree（抽象语法树）是编译器或解析器将源代码转换出的树形结构：每个节点表示一种语法成分，父子边表示代码的嵌套关系。它描述代码“怎么写”，不直接描述硬件电路如何执行。

## 在 Verilog 中
以 `assign out = a & b;` 为例，可抽象为：

```text
Assign
├── out
└── And
    ├── a
    └── b
```

`Assign` 是连续赋值语句，`out` 是左值，`And` 是按位与运算，`a` 与 `b` 是参与运算的标识符。解析器还可能生成 `Lvalue`、`Rvalue` 等包装节点；分析工具可省略它们以简化图。

## 核心要点
1. AST 保留语法层次，例如 `always` 内包含 `if`，`if` 内包含赋值语句。
2. AST 节点通常按语法类别命名，如 `Always`、`IfStatement`、`NonblockingSubstitution`、`Identifier`。
3. AST 是构建 [[CFG]] 与 [[DDG]] 的基础：前者从控制结构提取路径，后者从变量读写关系提取依赖。
4. AST 不是电路原理图、时序波形或执行路径；它不表达信号何时变化。

## 在 VerilogLAVD 中
[[VerilogLAVD]] 使用 PyVerilog 将 [[Verilog]] 源码解析为 AST，再将 AST 节点和 `AST` 父子关系写入 Neo4j。`veripg_construct.py` 会保留节点类型、行号、标识符名称等属性，为后续图遍历与漏洞模式检测提供结构化输入。

## 相关概念
- [[Verilog]]
- [[CFG]]
- [[DDG]]
- [[Cypher]]