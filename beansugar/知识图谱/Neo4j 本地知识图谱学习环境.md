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