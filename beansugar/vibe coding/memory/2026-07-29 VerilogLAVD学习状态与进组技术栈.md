# 2026-07-29 VerilogLAVD学习状态与进组技术栈

## 用户当前状态

- 用户正在进行研0阶段学习，目标是进入/适应杭电 CSL / Chip Security Lab 相关方向。
- 当前主线不是毕业论文写作，而是补齐 VerilogLAVD、知识图谱、硬件安全、程序分析等前置知识。
- 用户已经克隆并学习了 VerilogLAVD 项目，路径：`D:\project\VerilogLAVD`。
- 用户的 Obsidian 工作区：`D:\Obsidian\notes\笔记\beansugar`。

## 已看完的 VerilogLAVD 内容

核心文件已经基本讲解过：

- `D:\project\VerilogLAVD\src\traversal_engine\veripg_construct.py`
  - 作用：把 PyVerilog AST 转成 Neo4j 属性图。
  - 关键内容：AST 建图、CFG 建图、DDG 建图、赋值左右关系处理。
  - 重点函数：`create_node_by_astnode`、`ast2neo4j`、`cfg2neo4j`、`ddg2neo4j`、`create_relationship`。

- `D:\project\VerilogLAVD\src\traversal_engine\traversal_functions.py`
  - 作用：提供图遍历/查询函数，是检测模板的函数积木。
  - 已重点讲过：`Node`、`ASTOffspring`、`CFGOffspring`、`Always`、`If`、`Blocking`、`Nonblocking`、`DriverVar`、`LoadVar`、`ConditionVar`、`SensVar`。

- `D:\project\VerilogLAVD\src\traversal_engine\traversal_engine.py`
  - 作用：执行检测模板。
  - 已讲过：`self.session`、`self.funcs`、`execute`、`execute_path`、`apply_filter`、`combine_condition_results`。
  - 注意过一个可能的问题：`current_node is list` 很可能应为 `isinstance(current_node, list)`。

- `D:\project\VerilogLAVD\src\template_extraction\...`
  - 已大致讲过 LLM 生成 constraint path / vulnerability template 的部分。
  - 其中 `fsm.py` 是模板路径合法性验证用的有限状态机，不是 Verilog 里的硬件 FSM。

## 已完成的小测试

已经创建并运行过一个最小测试 notebook：

- `D:\project\VerilogLAVD\src\traversal_engine\1271_1_min_test.ipynb`

测试样例：

- `D:\project\VerilogLAVD\data\ImproperResourceOperate\1271\1271_1.v`

样例核心代码：

```verilog
always @(posedge clk) begin
    if (en) lock_jtag <= d;
end
```

测试结果要点：

- PyVerilog 能解析出 AST。
- VerilogLAVD 能写入 Neo4j 图。
- 图中约有 20 个节点、17 条边。
- 能识别：
  - `Always`
  - `IfStatement`
  - `NonblockingSubstitution`
  - `DriverVar: lock_jtag`
  - `LoadVar: d`

这个样例说明：VerilogLAVD 可以从 `lock_jtag <= d` 里识别出“左侧被驱动变量”和“右侧读取变量”，这是后续 CWE 检测的基础。

## 当前 Python / Neo4j 环境

Python 3.12：

- `D:\Anaconda2024\python.exe`

Python 3.12 额外包目录：

- `D:\pythonpackage\py312-packages`

Notebook 里通常需要加入：

```python
import sys

PACKAGE_DIR = r"D:\pythonpackage\py312-packages"
if PACKAGE_DIR not in sys.path:
    sys.path.insert(0, PACKAGE_DIR)
```

Neo4j 配置：

```python
NEO4J_URI = "neo4j://localhost:7687"
NEO4J_USERNAME = "neo4j"
NEO4J_PASSWORD = "password"
NEO4J_DATABASE = "neo4j"
```

Neo4j 可以通过 Docker 或 Neo4j Desktop 运行。之前 Docker 容器名为：

```text
neo4j-kg
```

连接测试代码：

```python
from neo4j import GraphDatabase

driver = GraphDatabase.driver(
    "neo4j://localhost:7687",
    auth=("neo4j", "password")
)

with driver.session(database="neo4j") as session:
    print(session.run("RETURN 'Neo4j connected' AS message").single()["message"])
```

## 已记录/创建过的 Obsidian 笔记

- `D:\Obsidian\notes\笔记\beansugar\知识图谱\Neo4j 本地知识图谱学习环境.md`
- `D:\Obsidian\notes\笔记\beansugar\论文笔记\_概念\0-待分类\AST抽象语法树.md`
- `D:\Obsidian\notes\笔记\beansugar\论文笔记\_概念\0-待分类\Verilog语法要点.md`

## 用户已理解或正在补的概念

Verilog：

- `module`
- `input/output`
- `wire/reg/logic`
- `always @(posedge clk)`
- `always @(*)`
- 阻塞赋值 `=`
- 非阻塞赋值 `<=`
- `if/case/for`
- FSM 状态机

程序分析：

- AST：抽象语法树，描述代码语法结构。
- CFG：控制流图，描述执行路径。
- DDG：数据依赖图，描述变量值影响关系。
- 静态分析：不运行代码，而是分析代码结构和语义。

Neo4j：

- Node / Relationship / Property / Label
- `MATCH`
- `CREATE`
- `MERGE`
- `WHERE`
- `RETURN`
- `elementId()`
- 可变长度路径，例如 `[:AST*0..]`

Python：

- `dict`
- `list`
- `self`
- `super()`
- 装饰器 `@register_func`
- `session.run()`
- `record["key"]` 与 `record.get("key")`

## 杭电 CSL / Chip Security Lab 进组前技术栈

优先级从高到低：

1. Verilog / SystemVerilog / 数字电路
   - 组合逻辑、时序逻辑、FSM、寄存器、锁存器。
   - 必须能读懂 RTL 代码。

2. 硬件安全基础
   - RTL security
   - Hardware CWE
   - JTAG / debug interface
   - security register
   - access control
   - secure boot
   - hardware Trojan
   - side channel / fault injection 可后置。

3. 程序分析
   - AST / CFG / DDG / PDG
   - 数据流分析
   - 控制流分析
   - 污点分析
   - pattern matching

4. 知识图谱 / Neo4j
   - 属性图建模
   - Cypher 查询
   - 路径查询
   - 图遍历

5. Python 工程
   - 脚本能力
   - 类和对象
   - 装饰器
   - JSON / CSV
   - Jupyter
   - conda / pip / PYTHONPATH

6. Verilog 解析工具链
   - PyVerilog
   - Icarus Verilog / iverilog
   - Verilator 可选
   - GTKWave 可选

7. LLM / RAG / Agent
   - Prompt
   - RAG
   - embedding
   - 向量检索
   - AutoGen
   - LLM 生成检测模板

## 推荐下一步

用户已经基本看完 VerilogLAVD 项目结构。下一步最建议：

1. 用 3-5 个自己写的小 Verilog 例子练习。
2. 每个例子跑 PyVerilog AST。
3. 再跑 VerilogLAVD 的 `VeriPG()` 写入 Neo4j。
4. 用 Cypher 查：
   - 哪些是 `Always`？
   - 哪些是 `IfStatement`？
   - 哪些是 `BlockingSubstitution` / `NonblockingSubstitution`？
   - `DriverVar` 是谁？
   - `LoadVar` 是谁？
   - 条件变量 `ConditionVar` 是谁？
5. 然后再读硬件 CWE 案例。

当前最适合继续做的任务：

- 围绕 `1271_1.v` 解释为什么它对应 CWE-1271。
- 或者新建几个 Verilog 小样例，对比阻塞/非阻塞、if/case、组合/时序逻辑在 AST/CFG/DDG 中的差异。
