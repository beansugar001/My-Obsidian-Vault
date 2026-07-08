---
type: concept
aliases: [Verilog语法, Verilog基础语法, RTL语法要点]
tags: [Verilog, RTL, 数字电路]
---

# Verilog语法要点

## 定义

[[Verilog]] 是硬件描述语言（HDL），用于描述数字电路的结构和行为。学习 Verilog 时要始终记住：Verilog 不是普通软件程序，而是在描述硬件电路。

## 基本结构

一个 Verilog 设计通常以 `module` 为单位：

```verilog
module and_gate (
    input  wire a,
    input  wire b,
    output wire y
);
    assign y = a & b;
endmodule
```

核心部分：

```text
module / endmodule：模块边界
input：输入端口
output：输出端口
wire：连线型信号
assign：连续赋值
```

## 信号类型

常见信号类型：

```verilog
wire a;
reg q;
logic x;   // SystemVerilog 中更常用
```

要点：

```text
wire：表示连线，常用于 assign 连续赋值左侧或模块连接
reg：表示过程块中被赋值的变量，不一定真的综合成寄存器
logic：SystemVerilog 类型，可替代大多数 wire/reg 用法
```

初学规则：

```text
assign 左边通常用 wire
always 块中被赋值的信号通常用 reg / logic
```

## 位宽、切片与拼接

定义多位信号：

```verilog
wire [7:0] data;
reg  [3:0] state;
```

位选择和切片：

```verilog
assign bit0 = data[0];
assign high = data[7:4];
```

拼接：

```verilog
assign out = {a, b};
```

重复拼接：

```verilog
assign mask = {8{1'b1}};
```

## 常量写法

Verilog 常量格式：

```text
位宽'进制数值
```

例子：

```verilog
4'b1010   // 4 位二进制
8'hff     // 8 位十六进制
16'd100   // 16 位十进制
1'b0      // 1 位二进制 0
```

常见进制：

```text
b：binary 二进制
h：hex 十六进制
d：decimal 十进制
o：octal 八进制
```

## 连续赋值 assign

`assign` 描述组合逻辑，左边通常是 `wire`：

```verilog
assign y = a & b;
assign sum = x + z;
```

特点：

```text
右侧信号变化时，左侧会立即随组合逻辑变化
适合描述门级组合逻辑、简单表达式、连线关系
```

在 AST 中常对应 `Assign` 节点。

## always 过程块

### 组合逻辑 always @(*)

```verilog
always @(*) begin
    y = a & b;
end
```

要点：

```text
always @(*) 用于组合逻辑
组合逻辑中通常使用阻塞赋值 =
每条路径都要给输出赋值，避免推断锁存器 latch
```

推荐写法：

```verilog
always @(*) begin
    y = 1'b0;
    if (en) begin
        y = a;
    end
end
```

### 时序逻辑 always @(posedge clk)

```verilog
always @(posedge clk) begin
    q <= d;
end
```

要点：

```text
posedge clk 表示时钟上升沿触发
时序逻辑中通常使用非阻塞赋值 <=
常用于寄存器、状态机、计数器
```

带复位：

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        q <= 1'b0;
    else
        q <= d;
end
```

## 阻塞赋值与非阻塞赋值

阻塞赋值：

```verilog
a = b;
```

特点：

```text
立即赋值
后续语句能看到新值
常用于组合逻辑 always @(*)
```

非阻塞赋值：

```verilog
a <= b;
```

特点：

```text
先计算右侧，当前时间步末尾统一更新左侧
同一个时钟沿内，右侧读到的是旧值
常用于时序逻辑 always @(posedge clk)
```

对比：

```verilog
always @(posedge clk) begin
    q1 <= d;
    q2 <= q1;
end
```

含义：`q2` 得到的是旧的 `q1`，形成两级寄存器。

如果写成阻塞赋值：

```verilog
always @(posedge clk) begin
    q1 = d;
    q2 = q1;
end
```

仿真中 `q2` 可能立刻得到新的 `d`，这通常不是想要的寄存器级联行为。

## if / else

```verilog
always @(*) begin
    if (sel)
        y = a;
    else
        y = b;
end
```

要点：

```text
if 表示条件选择逻辑
组合逻辑中要覆盖所有分支
时序逻辑中常用于复位、使能、状态跳转
```

在 PyVerilog AST 中常对应 `IfStatement`。

## case

```verilog
always @(*) begin
    case (sel)
        2'b00: y = a;
        2'b01: y = b;
        2'b10: y = c;
        default: y = 1'b0;
    endcase
end
```

要点：

```text
case 用于多路选择
组合逻辑中建议写 default，避免不完整赋值导致 latch
case 条件通常是状态变量、选择信号或操作码
```

在 PyVerilog AST 中常对应 `CaseStatement`。

## for 循环

Verilog 中的 `for` 常用于生成重复硬件结构或在过程块中描述重复赋值：

```verilog
integer i;
always @(*) begin
    for (i = 0; i < 8; i = i + 1) begin
        y[i] = a[i] & b[i];
    end
end
```

要点：

```text
Verilog for 循环通常会被综合展开成硬件结构
循环次数最好是静态可确定的
不要把它简单理解成软件运行时循环
```

在 PyVerilog AST 中常对应 `ForStatement`。

## FSM 状态机基本写法

状态机通常包含：

```text
状态寄存器
下一状态逻辑
输出逻辑
```

简化模板：

```verilog
localparam IDLE = 2'b00;
localparam RUN  = 2'b01;

reg [1:0] state, next_state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start)
                next_state = RUN;
        end
        RUN: begin
            if (done)
                next_state = IDLE;
        end
        default: begin
            next_state = IDLE;
        end
    endcase
end
```

安全分析中，FSM 很重要，因为很多硬件漏洞来自错误状态转移、非法状态未处理、权限状态绕过。

## 常见运算符

```text
&  按位与
|  按位或
^  按位异或
~  按位取反
&& 逻辑与
|| 逻辑或
!  逻辑非
== 相等比较
!= 不等比较
< <= > >= 比较
+ - * 算术运算
<< >> 移位
? : 条件运算符
```

注意：

```text
& 和 && 不一样
| 和 || 不一样
```

例如：

```verilog
assign y1 = a & b;    // 按位与
assign y2 = a && b;   // 逻辑与
```

## 常见初学错误

1. 在时序逻辑中误用阻塞赋值 `=`。
2. 在组合逻辑中分支赋值不完整，导致 latch。
3. 位宽不匹配导致截断或补零。
4. 忘记 `default` 分支。
5. 混淆 `wire`、`reg`、`logic`。
6. 把 Verilog `for` 当成普通软件循环。
7. 在多个 `always` 块中驱动同一个信号。

## 与 AST / CFG / DDG 的关系

VerilogLAVD 会把 Verilog 代码解析成 [[AST]]，再构建 [[CFG]] 和 [[DDG]]。

语法对应关系：

```text
assign -> Assign
always -> Always
if / else -> IfStatement
case -> CaseStatement
for -> ForStatement
= -> BlockingSubstitution
<= -> NonblockingSubstitution
变量名 -> Identifier
整数常量 -> IntConst
```

例如：

```verilog
always @(posedge clk) begin
    if (en)
        q <= d;
end
```

可以抽象为：

```text
Always
└── IfStatement
    ├── Identifier(en)
    └── NonblockingSubstitution
        ├── Identifier(q)
        └── Identifier(d)
```

其中：

```text
AST：描述 Always 包含 If，If 包含赋值
CFG：描述 if 条件为真时进入赋值分支
DDG：描述 d 的值影响 q 的更新
```

## VerilogLAVD 学习重点

为了读懂 [[VerilogLAVD]]，需要重点掌握：

```text
1. assign、always、if、case、for 的语法结构
2. 阻塞赋值和非阻塞赋值的区别
3. Identifier、Assign、Always、IfStatement 等 AST 节点含义
4. 变量读写关系：左值是被写信号，右值是被读取信号
5. 状态机和控制逻辑的常见写法
```

## 相关概念

- [[Verilog]]
- [[AST]]
- [[CFG]]
- [[DDG]]
- [[FSM]]
- [[State Transition Graph]]