---
type: note
aliases: [Neo4j本地环境, 知识图谱学习环境, Neo4j连接]
tags: [知识图谱, Neo4j, Docker, Python, Jupyter]
---

# Neo4j 本地知识图谱学习环境

## 当前环境

当前 notebook 文件：

```text
D:\project\neo4j\knowledge_graph_query.ipynb
```

Python 3.12 路径：

```text
D:\Anaconda2024\python.exe
```

Python 3.12 额外包目录：

```text
D:\pythonpackage\py312-packages
```

该目录用于放 `neo4j`、`python-dotenv` 等轻量依赖。`pandas` 和 `numpy` 使用 Anaconda 3.12 自带版本，避免混用旧的 `D:\pythonpackage\packages`。

## Neo4j Desktop 与 Docker

Neo4j 可以由 Desktop 或 Docker 提供服务。notebook 中：

```python
NEO4J_URI = "neo4j://localhost:7687"
```

只表示连接本机 `7687` 端口上的 Neo4j 服务，不直接说明服务来自 Docker 还是 Neo4j Desktop。

本次检查结果：

```text
127.0.0.1:7474 LISTENING java.exe
127.0.0.1:7687 LISTENING java.exe
```

该 `java.exe` 来自 Neo4j Desktop：

```text
C:\Users\24796\.Neo4jDesktop2\Cache\runtime\...
```

Docker 容器状态为：

```text
neo4j-kg Exited (137)
```

所以当前实际连接链路是：

```text
Notebook -> localhost:7687 -> Neo4j Desktop
```

不是：

```text
Notebook -> localhost:7687 -> Docker neo4j-kg
```

## 端口含义

```text
7474：Neo4j Browser 网页入口
7687：Bolt 协议端口，Python driver 通过它连接 Neo4j
```

端口负责找到服务，不决定数据库名称。

## 实例名、容器名、数据库名

容易混淆的三个名字：

```text
kg-course：Neo4j Desktop 中的本地实例名
neo4j-kg：Docker 容器名
neo4j：Neo4j 内部默认数据库名
```

代码中的：

```python
NEO4J_DATABASE = "neo4j"
```

指的是 Neo4j DBMS 内部的默认数据库，不是 Desktop 实例名，也不是 Docker 容器名。

Neo4j 默认结构可理解为：

```text
Neo4j DBMS 实例
├── system 数据库
└── neo4j 数据库
```

业务数据通常放在 `neo4j` 数据库中。

## Notebook 中的 Python 路径

为了让 Python 3.12 找到额外安装的包，notebook 开头加入：

```python
import sys

PACKAGE_DIR = r"D:\pythonpackage\py312-packages"
if PACKAGE_DIR not in sys.path:
    sys.path.insert(0, PACKAGE_DIR)
```

`sys.path` 是 Python 导入模块时搜索包的位置列表。把 `D:\pythonpackage\py312-packages` 放进去后，Python 就能导入其中的 `neo4j` 和 `dotenv`。

## 创建 Neo4j driver

```python
driver = GraphDatabase.driver(
    NEO4J_URI,
    auth=(NEO4J_USERNAME, NEO4J_PASSWORD),
)
```

含义：创建一个 Neo4j driver 对象，也就是 Python 连接 Neo4j 的入口。

常用配置：

```python
NEO4J_URI = "neo4j://localhost:7687"
NEO4J_USERNAME = "neo4j"
NEO4J_PASSWORD = "password"
NEO4J_DATABASE = "neo4j"
```

## 打开 session 并测试连接

```python
with driver.session(database=NEO4J_DATABASE) as session:
    message = session.run("RETURN 'Neo4j connected' AS message").single()["message"]

print(message)
```

含义：

1. `driver.session(database=NEO4J_DATABASE)` 打开数据库会话。
2. `with ... as session` 会在代码块结束后自动关闭 session。
3. `session.run(...)` 执行 Cypher 查询。
4. `.single()` 取唯一一行结果。
5. `["message"]` 取字段名为 `message` 的值。

Cypher：

```cypher
RETURN 'Neo4j connected' AS message
```

如果输出：

```text
Neo4j connected
```

说明 Python 与 Neo4j 连接正常。

## 字典取值与 Record 取值

Python 字典可以用 `[]` 根据 key 取 value：

```python
person = {"name": "Andrew Ng"}
print(person["name"])
```

Neo4j 的 `Record` 对象也支持类似写法：

```python
record["message"]
```

如果不确定字段是否存在，可以用：

```python
record.get("message")
```

注意 `.get` 是方法，必须用小括号，不能写成：

```python
record.get["message"]  # 错误
```

## run_cypher 工具函数

```python
def run_cypher(query: str, params: dict | None = None) -> pd.DataFrame:
    """执行 Cypher 查询，并把结果转成 pandas DataFrame。"""
    with driver.session(database=NEO4J_DATABASE) as session:
        result = session.run(query, params or {})
        return pd.DataFrame([record.data() for record in result])
```

作用：传入 Cypher 查询，返回 pandas 表格。

例如：

```python
run_cypher("MATCH (n) RETURN n LIMIT 5")
```

### 参数

```python
query: str
```

表示 Cypher 查询语句。

```python
params: dict | None = None
```

表示参数可以是字典，也可以是 `None`。这是 Python 3.10+ 的类型标注写法，当前 Python 3.12 可以使用。

参数查询示例：

```python
run_cypher(
    "MATCH (p:Person {name: $name}) RETURN p.name AS name",
    {"name": "Andrew Ng"}
)
```

Cypher 中的 `$name` 会由参数字典中的值绑定。

### params or {}

```python
params or {}
```

含义：

```text
如果 params 有值，就使用 params；
如果 params 是 None，就使用空字典 {}。
```

### record.data()

```python
[record.data() for record in result]
```

这是列表推导式。它遍历 Neo4j 查询结果，把每行 `Record` 转为字典。

例如：

```python
{"name": "Andrew Ng", "topic": "Knowledge Graph"}
```

最后：

```python
pd.DataFrame(...)
```

把字典列表转换成表格。

## Python 版本注意点

`dict | None` 是 Python 3.10+ 写法。

如果使用 Python 3.9，会报：

```text
TypeError: unsupported operand type(s) for |: 'type' and 'NoneType'
```

Python 3.9 兼容写法：

```python
from typing import Optional

def run_cypher(query: str, params: Optional[dict] = None) -> pd.DataFrame:
    ...
```

当前知识图谱学习环境使用 Python 3.12，因此可以保留 `dict | None`。

## 常用检查命令

查看 Docker 中是否有 Neo4j 容器：

```powershell
docker ps -a | findstr neo4j
```

启动 Docker Neo4j 容器：

```powershell
docker start neo4j-kg
```

停止 Docker Neo4j 容器：

```powershell
docker stop neo4j-kg
```

检查本机端口：

```powershell
netstat -ano | findstr :7687
netstat -ano | findstr :7474
```

根据 PID 查看进程：

```powershell
tasklist /FI "PID eq 8332"
```

如果端口对应 Neo4j Desktop 的 Java 进程，说明当前 notebook 连接的是 Neo4j Desktop。

## 当前建议

学习阶段继续使用 Neo4j Desktop 即可，因为它直观、容易查看图数据。

只需要保证：

```text
1. Neo4j Desktop 中的数据库实例正在运行
2. localhost:7687 可以连接
3. notebook 中的用户名、密码、数据库名正确
```
## SEC 添加关系课程要点

“向 SEC 知识图谱中添加关系”的核心不是 SEC 业务本身，而是学习如何把实体和关系写入 Neo4j。

基本流程：

```text
1. 确定实体节点
2. 确定实体之间的语义关系
3. 用 MERGE / MATCH 创建节点和边
4. 查询验证图谱是否正确
```

常见 SEC 图谱节点：

```text
Company：公司
Form：SEC 表单
Ticker：股票代码
CIK：公司识别码
Industry：行业
Manager：管理者
```

常见关系：

```text
Company -[:FILED]-> Form
Company -[:HAS_TICKER]-> Ticker
Company -[:HAS_CIK]-> CIK
Company -[:IN_INDUSTRY]-> Industry
Manager -[:WORKS_FOR]-> Company
```

创建关系的标准 Cypher 模式：

```cypher
MERGE (c:Company {cik: $cik})
MERGE (f:Form {formId: $formId})
MERGE (c)-[:FILED]->(f)
```

`MERGE` 的作用是：存在就匹配，不存在就创建。相比 `CREATE`，它可以减少重复节点和重复关系。

带属性的关系：

```cypher
MERGE (c)-[r:FILED]->(f)
ON CREATE SET
    r.source = "SEC",
    r.filedAt = $filedAt
```

课程里常见参数传入方式：

```python
kg.query(cypher, params={"formInfoParam": form_info})
```

Cypher 中可以这样使用嵌套参数：

```cypher
$formInfoParam.formId
$formInfoParam.cik
$formInfoParam.names
```

## 与 VerilogLAVD 的对应关系

SEC 知识图谱和 VerilogLAVD 的底层图思想相同：都是把对象建成节点，把对象之间的关系建成边。

SEC 图谱：

```text
Company -[:FILED]-> Form
Company -[:IN_INDUSTRY]-> Industry
```

VerilogLAVD：

```text
Assign -[:AST {condition: "left"}]-> Identifier
IfStatement -[:CFG {condition: "true"}]-> Statement
Decl -[:DDG]-> Assign
```

区别在于对象不同：

```text
SEC：公司、表单、行业、证券代码等业务实体
VerilogLAVD：Always、IfStatement、Assign、Identifier 等代码结构
```

VerilogLAVD 里对应的代码位置：

```text
create_node_by_astnode()：创建 Neo4j 节点
create_relationship()：创建 Neo4j 关系
set_assign_relationship()：给赋值语句左右两侧加 left/right 关系
cfg2neo4j()：创建控制流 CFG 关系
ddg2neo4j()：创建数据依赖 DDG 关系
```

因此，学习 SEC 添加关系课程时，重点关注：

```text
MERGE 如何创建节点
MERGE 如何创建关系
关系方向怎么设计
关系属性怎么设置
如何避免重复节点和重复边
如何用 MATCH 验证创建结果
```

SEC 的金融业务细节可以暂时略看。

## VerilogLAVD 还需要补的技术栈

当前已经补上的部分：

```text
Neo4j 基础
Cypher 查询
属性图模型
Python 连接 Neo4j
向图谱中添加节点和关系
```

接下来建议按以下顺序补齐。

### 1. Verilog 语义

重点掌握：

```text
module / port / wire / reg / logic
assign 连续赋值
always @(*) 组合逻辑
always @(posedge clk) 时序逻辑
阻塞赋值 = / 非阻塞赋值 <=
if / case / for
位宽、切片、拼接
FSM 写法
```

目标：看到 Verilog 代码，能判断它是组合逻辑、时序逻辑、状态机，还是普通赋值结构。

### 2. PyVerilog

VerilogLAVD 使用 PyVerilog 解析 Verilog 源码。

需要理解：

```text
parse()
AST 节点类型
children()
attr_names
Identifier
Assign
Always
IfStatement
BlockingSubstitution
NonblockingSubstitution
```

目标：给一个小 Verilog 文件，能打印 AST，并看懂主要节点。

### 3. AST / CFG / DDG

需要和 VerilogLAVD 代码结合理解：

```text
AST：语法结构，表示代码“怎么嵌套”
CFG：控制流，表示执行可能“从哪里走到哪里”
DDG：数据依赖，表示变量值“从哪里影响到哪里”
```

在 VerilogLAVD 中：

```text
AST 边：语法父子关系
CFG 边：always / if / for / case 的执行路径
DDG 边：变量声明、使用、赋值之间的数据依赖
```

### 4. Cypher 路径查询

VerilogLAVD 的遍历函数大量依赖路径查询。

重点语法：

```cypher
MATCH (a)-[:AST]->(b)
MATCH (a)-[:AST*0..]->(b)
MATCH p = (a)-[:CFG*0..5]->(b)
RETURN nodes(p), relationships(p)
WHERE elementId(a) = $id
RETURN DISTINCT elementId(b)
```

关系属性查询：

```cypher
MATCH (n)-[r:AST]->(m)
WHERE r.condition = "left"
RETURN m
```

对应 VerilogLAVD 函数：

```text
ASTOffspring
CFGOffspring
DriverVar
LoadVar
ConditionVar
GetBranch
```

### 5. traversal_engine.py

这是 VerilogLAVD 的模板执行器。

需要理解：

```text
Func：调用哪个图查询函数
Params：传什么参数
Path：沿图连续执行多步
Filter：对候选节点做筛选
```

目标：能看懂一个检测模板如何被转换成一连串 Neo4j 查询。

### 6. 硬件安全 CWE 基础

VerilogLAVD 的目标是检测 Verilog CWE，因此需要补一点硬件安全背景。

先掌握：

```text
CWE 是什么
硬件漏洞和软件漏洞的区别
权限控制错误
调试/测试接口未关闭
状态机错误
复位逻辑问题
锁定机制绕过
信息泄露
```

目标：看到一个检测模板时，能理解它想找哪类硬件安全问题。

### 7. LLM 模板生成部分后置

`template_extraction/` 目录涉及：

```text
LLM prompt
约束路径
模板生成
路径验证
AutoGen
```

这部分可以放到后面。当前优先吃透 `traversal_engine/`。

## 下一步实践建议

先写 3 个小 Verilog 例子：

```text
1. assign out = a & b;
2. always @(posedge clk) q <= d;
3. if / else 状态机片段
```

然后用 PyVerilog 打印 AST，并对照 VerilogLAVD 的建图逻辑：

```text
Verilog 代码
  -> PyVerilog AST
  -> Neo4j AST 节点与 AST 边
  -> CFG / DDG 边
  -> traversal_engine 图遍历
```

这条线打通后，再继续看 `traversal_functions.py` 和 `traversal_engine.py` 会更顺。
