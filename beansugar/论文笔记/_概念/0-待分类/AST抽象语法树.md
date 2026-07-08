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


## 与 CST 的区别

CST（Concrete Syntax Tree，也称 Parse Tree）更接近语法分析过程，会保留完整的语法细节，例如括号、分号、关键字层级和语法产生式。

AST 则会去掉一部分语法噪声，只保留后续分析真正需要的结构。例如表达式 `a & b` 在 AST 中通常只需要保留 `And(a, b)` 这种语义结构，而不需要保存所有语法产生式节点。

在代码分析任务中通常更关注 AST，因为它更适合回答：

```text
这个语句是什么类型？
赋值左边是谁？
赋值右边用了哪些变量？
if 条件里出现了哪些标识符？
always 块内部包含哪些语句？
```

## PyVerilog AST 读取方式

[[PyVerilog]] 解析 [[Verilog]] 后会生成 AST 节点对象。常见字段和方法包括：

```python
ast_node.__class__.__name__
ast_node.children()
ast_node.attr_names
ast_node.lineno
```

含义：

```text
__class__.__name__：AST 节点类型名，例如 Always、IfStatement、Identifier
children()：返回当前节点的子节点
attr_names：当前节点有哪些重要属性
lineno：该节点对应的源码行号
```

例如 `Identifier(name='clk')` 表示一个标识符节点，它的变量名是 `clk`。

常见 PyVerilog AST 节点：

```text
Source：源码根节点
Description：设计描述
ModuleDef：模块定义
Always：always 块
IfStatement：if 语句
Assign：assign 连续赋值
BlockingSubstitution：阻塞赋值 =
NonblockingSubstitution：非阻塞赋值 <=
Identifier：变量名 / 信号名
IntConst：整数常量
```

## VerilogLAVD 建图细节

在 [[VerilogLAVD]] 中，`veripg_construct.py` 会把 PyVerilog AST 节点转换成 Neo4j 属性图节点。

核心映射关系：

```text
PyVerilog AST 节点类型 -> Neo4j 节点 label
ast_node.lineno -> Neo4j 属性 lineno
ast_node.__class__.__name__ -> Neo4j 属性 name
ast_node.name -> Neo4j 属性 label
```

例如 Verilog 中的变量 `clk`，在 PyVerilog 中可能是：

```text
Identifier(name='clk')
```

写入 Neo4j 后大致变成：

```text
(:Identifier {
    name: "Identifier",
    label: "clk",
    lineno: 行号
})
```

这里要区分：

```text
name：AST 节点类型，例如 Identifier
label：Verilog 代码里的具体名字，例如 clk
```

之所以把 `ast_node.name` 存成 `label`，是为了避免覆盖节点类型字段 `name`。

## 跳过包装节点

VerilogLAVD 会跳过一些包装型 AST 节点：

```python
skip_nodes = ["Var", "Lvalue", "Rvalue", "Block"]
delete_nodes = ["Source", "Description", "ModuleDef"]
```

“跳过”不是完全丢弃信息，而是把这些节点的子节点提上来继续处理，让 Neo4j 图更简洁。

例如原始 AST 可能是：

```text
Assign
├── Lvalue
│   └── Identifier(out)
└── Rvalue
    └── And
        ├── Identifier(a)
        └── Identifier(b)
```

跳过 `Lvalue` 和 `Rvalue` 后，图中可以简化为：

```text
Assign
├── Identifier(out)
└── And
    ├── Identifier(a)
    └── Identifier(b)
```

后续 `set_assign_relationship()` 会重新给赋值左右两边打上关系属性：

```text
Assign -[:AST {condition: "left"}]-> Identifier(out)
Assign -[:AST {condition: "right"}]-> And
```

## 在漏洞检测中的作用

AST 是 VerilogLAVD 后续 [[CFG]]、[[DDG]] 和图模式检测的基础。

典型用途：

```text
1. 通过 AST 找赋值语句左边和右边。
2. 通过 AST 找 if 条件中出现的变量。
3. 通过 AST 找 always 块内部语句。
4. 通过 AST 找 case 分支、循环体和表达式结构。
5. 为 CFG 控制流边和 DDG 数据依赖边提供基础节点。
```

例如检测赋值相关模式时，需要知道：

```text
被写入的信号是谁？
右侧读取了哪些信号？
这个赋值位于哪个 always / if / case 内？
```

这些问题都需要先依赖 AST 图回答。

## 在 VerilogLAVD 中
[[VerilogLAVD]] 使用 PyVerilog 将 [[Verilog]] 源码解析为 AST，再将 AST 节点和 `AST` 父子关系写入 Neo4j。`veripg_construct.py` 会保留节点类型、行号、标识符名称等属性，为后续图遍历与漏洞模式检测提供结构化输入。

## 相关概念
- [[Verilog]]
- [[CFG]]
- [[DDG]]
- [[Cypher]]