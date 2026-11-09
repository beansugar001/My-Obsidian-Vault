# CY63300 I²C 黑盒恢复：V7.6/V7.7 写路径判别结果

> **状态更新（2026-11-05 13:05 CST）：** 下方 V7.6/V7.7 是有效历史记录，但其中“暂停所有 I²C 控制器写入”的旧结论已被后续受控阶段更新。V7.8 证明当前使用的 V4.4 连续 SBA 顺序可写 SYSCTRL 与 I²C DIV0；V8.0B–V8.0G 配置并验证了 Pad8/9；V8.3 启用 FIFO；V8.4B 单独启用 I2C_EN 后读回正确，V8.4C 又在空闲时关闭它。**当前尚未发出 START，真实 I²C 通信仍未验证。**完整最新状态见 [`06_PROGRESS_20261105.md`](06_PROGRESS_20261105.md)。

## 后续受控实物阶段 V7.8–V8.4C（新增）

### V7.8：重现 V4.4 SBA 访问顺序

- `BBX_V78_V44_ORDER_CLOCK_01`：将 `PERI_CLKEN` 从0写到`0x20`，独立读回两次均为`0x20`。一次目标写，PASS。
- `BBX_V78B_V44_ORDER_DIV0_01`：将 `CLK_DIV0` 从`0x20`写为`0x21`，独立读回两次均为`0x21`。一次目标写，PASS。
- `BBX_V78C_DIV0_RESTORE_01`：恢复`CLK_DIV0=0x20`，独立读回一致。一次目标写，PASS。
- 结果：V7.6/7.3 失败并非足以证明芯片所有 SBA 写路径永久失效；访问命令顺序/会话状态是重要差异。禁止将早期失败解释继续泛化。

### V7.9–V8.3：Pad 与外设基线

- V7.9 打开 GPIO 外设时钟；V8.0B 读到 Pad8/PB2、Pad9/PB3 的 AF0、非开漏、无上拉，两个输入位为低。
- V8.0C 先预置 ODR 高，V8.0D 配开漏，V8.0E 配 GPIOB pull-up（脚本初次字段解码误判，原始日志保留并有独立解释更正），V8.0F 设输出方向且保持释放，V8.0G 设 AF3。此后读回 AF3/OD/上拉正确，输入位高。
- V8.1–V8.2 只读确认控制器默认配置及 SYSCTL 时钟；默认分频推算约195.1 kHz（假设手册所述 nominal PCLK=16 MHz，尚无示波器实测）。
- V8.3 用一次写将 TX/RX FIFO 使能，读回有效 MODULE_CTRL=`0x0E`，I2C_EN 仍为0，FIFO 空。

### V8.4 地址错误与纠正

- `BBX_V84_I2C_CONTROLLER_ENABLE_01` 在写入前发现脚本把 I2C_STA 读到`0x4000282C`。手册实际说明 `I2C_STA` offset 是`0x3C`，`0x2C` 是 I2CM_CODE。该阶段失败、目标写次数0；日志/marker保留，未重跑。
- 新阶段 V8.4B 用正确状态地址，检查 IDCODE、halted/DMSTATUS、SBCS、时钟/复位、分频、FIFO、GPIO pad 和状态后，只写一次`MODULE_CTRL 0x0E→0x0F`，即仅置 I2C_EN。读回两次`0x0F`、FIFO仍空、`I2C_STA(0x3C)=0`、`RAW_INTR_STA(0x58)=0`、Pad8/9 输入高。PASS；没有START。
- V8.4C 为遵循 ARM 样例“配置地址后启用”的顺序，在确认控制器 idle、FIFO 空后只写一次`MODULE_CTRL 0x0F→0x0E`，并独立读回两次。PASS。**当前 I2C_EN 为0。**
- 本轮新增阶段原始证据分别位于 `runs/BBX_V78*` 至 `runs/BBX_V84C*`，marker 只增不删，详见 `06_PROGRESS_20261105.md`。

### 下一步

外部从机身份/地址尚未确认，禁止对未知设备做全地址扫描。确认具体模块供电、GND、SCL/SDA 和地址脚后，准备读取该器件明确只读的身份寄存器；优先用示波器/逻辑分析仪验证 START、地址 ACK、重复START、数据和 STOP。若没有从机或地址不明，先解决连接/身份，不继续写控制器值。

日期：2026-11-05  
V7.6/V7.7 当时状态：**I²C 实物恢复未完成；暂停所有目标外设写入。**该历史判断已由文件开头所述 V7.8–V8.4C 新证据更新；最新状态见 [`06_PROGRESS_20261105.md`](06_PROGRESS_20261105.md)。

## 结论摘要

当前目标（探针序列号 `07000001006700343500000a4e57354aa5a5a5a597969908`）JTAG 识别正常，IDCODE=`0x1E200A6F`，单Hart可halt，DMSTATUS=`0x00430382`，SBCS=`0x20040404`。但两条独立写入途径都没有给出目标数据变化证据：

1. SBA 写 SYSCTRL `PERI_CLKEN` 一次后，513 ms内读回仍为0。
2. SBA 写 map已确认安全的SRAM图样后，读回仍是原值。
3. Debug Module 的 Program Buffer `postexec` 命令返回无 `cmderr`，但 `addi x7,x7,1` 没有改变x7；CPU `sw` 图样也没有改变SRAM读回。

因此当前最优先的问题是 Debug Module 写入/Program Buffer执行/目标事务提交路径，而不是继续枚举I²C控制寄存器值。SBCS无错误或DMI命令返回成功都不足以证明目标接受了写操作。

## V7.6 实物阶段

| 阶段 | 操作和结果 | 结论 | 原始记录 |
|---|---|---|---|
| `BBX_V76A_CLOCK_GATE_DELAY_02` | 前置读数 `PERI_RST=0`、`PERI_CLKEN=0`，各三次；CPU在本会话halt；一次SBA写 `0x4002180C <- 0x20`；约7/163/319/513ms读回均为0；SBCS持续`0x20040404` | 写未对SBA读回可见；不知道内部请求是否到达SYSCTRL | [runs目录](runs/BBX_V76A_CLOCK_GATE_DELAY_02_20261105_114920_842094/)，combined SHA-256 `0EBBD0E27DCE2C5969D6AB305260FBCEE0BC48C55F746DD0562FE99771BF7D3D` |
| `BBX_V76B_SRAM_WRITE_CONTROL_01` | 地址`0x20008000`原值两读稳定`0xD7F5F64F`；SBA请求写`0xA5A55A5A`后仍读原值；随后请求写回原值并读到同一值 | SRAM图样写不可见。由于图样从未出现，后续同值读回**不能证明恢复写提交**；但当前读回仍显示原值 | [runs目录](runs/BBX_V76B_SRAM_WRITE_CONTROL_01_20261105_115432_978652/)，combined SHA-256 `3ABBBDBBC42B112C3A16FBBE66E5FDC672C7594943CD28696406F67C0F344442` |

## V7.7 实物阶段

| 阶段 | 操作和结果 | 写入/状态边界 | 原始记录 |
|---|---|---|---|
| `BBX_V77_CPU_STORE_SRAM_01` | 在读取x10/x11/DPC后，脚本因把`ABSTRACTCS`的datacount低位误判为busy而停止；没有执行Program Buffer或目标存储写入 | halt一次；目标MMIO/内存写0。保留失败marker | [runs目录](runs/BBX_V77_CPU_STORE_SRAM_01_20261105_120421_072372/)，combined SHA-256 `BD94B11E59520803AFF3E46E6284272D14C63E385171F1DE3F860584D37C2D3E` |
| `BBX_V77_CPU_STORE_SRAM_02` | 修正busy为ABSTRACTCS bit12后，发现Program Buffer读回0；脚本在写SRAM前停止。该类PROGBUF可能只写，不能用0读回推断写入未成功 | 没有目标内存/MMIO写；仅请求Program Buffer NOP后又请求写回读到的0，不能证明其原值 | [runs目录](runs/BBX_V77_CPU_STORE_SRAM_02_20261105_120615_458519/)，combined SHA-256 `A8D510EB91D49D28A00D72A95CF52866088CCF3914F29AB46691B600A35AD224` |
| `BBX_V77_CPU_STORE_SRAM_03` | 依据“PROGBUF可能只写”修订：稳定读出SRAM原值`0xD7F5F64F`；临时设置x10=`0x20008000`、x11=`0x280A09B0`；请求`sw x11,0(x10)`后SBA仍读`0xD7F5F64F`；预定原值store后仍读`0xD7F5F64F`；x10/x11/DPC最终读回原值；末尾请求NOP | CPU store尝试1次、原值恢复请求1次；真实SRAM在独立读路径上始终显示原值，但恢复请求本身无法单独证明提交。没有目标MMIO写；未发显式resume/reset命令。DPC同值抽象写后阶段末DMSTATUS由`0x00430382`转为`0x00430C82`（running形态），可能有隐藏状态副作用 | [runs目录](runs/BBX_V77_CPU_STORE_SRAM_03_20261105_120913_079068/)，combined SHA-256 `1F4B2046E23BD09526B073310992826045BBBD49C71F9D5F37CF0640C89E7C28` |
| `BBX_V77_PROGBUF_GPR_01` | 抽象命令将x7设为`0x12345800`且读回一致；请求Program Buffer执行`addi x7,x7,1`；ABSTRACTCS无busy/cmderr、DMSTATUS仍halted，但x7还是`0x12345800`；x7/DPC恢复读回一致；末尾请求NOP | 未写SRAM/MMIO；x7/DPC恢复已核验。Program Buffer写请求不能独立读回 | [runs目录](runs/BBX_V77_PROGBUF_GPR_01_20261105_121141_042148/)，combined SHA-256 `442A1DEB96D5255D8D29FB5D1616ED8C16680B6B247227D325D848F963451343` |

注：报告目录名中的微秒尾缀应以`runs/`下实际目录为准；不改写历史日志。每个原始运行目录包含实际argv/cwd/输入哈希、stdout、stderr、combined log和result JSON。OpenOCD stdout为空，工具输出主要在stderr，这是此次捕获方案的正常表现。

## 静态证据如何解释

- 数字设计说明区分SYSCTRL AHB3与I²C APB5；I²C寄存器地址和时钟/复位位定义以RISC-V版本手册为准。
- ARM驱动确认参考初始化顺序为先时钟、分频、MCTR/HOLD、FIFO、MODE、再按样例配置主机通信；PAD8/PAD9为当前唯一手册确认的主机SCL/SDA双向组合。该流程不能解释为何当前普通SBA写不改变SRAM。
- 现有V5.2 `jtag_dm.v`参考实现的COMMAND分支没有执行`postexec=1` Program Buffer的逻辑，却仍可通过常规DMI响应返回成功；其DPC抽象写分支会置位`dm_reset_req`并将DMSTATUS标为running。真实芯片观察与模型表现有相似处，但项目中没有流片DM/总线RTL；不能把参考RTL当成ASIC根因。特别是本轮DPC同值恢复后观察到DMSTATUS=`0x00430C82`，后续不再抽象写DPC。
- 当前实测的GPR抽象读写可读回，证明DMI/JTAG并非整体失灵；但SBA目标写与Program Buffer执行均未验证成功。
- V4.4早期成功日志和本轮失败日志不应直接拼成“同一芯片前后状态变化”：历史样片/批次/调试器身份尚未证实一致。

## 风险与下一步

已停止继续试写I²C寄存器。下一步先向旗捷/设计方确认：

1. 当前流片版DM对`progbufsize=1`、`impebreak=1`和`postexec`的正式支持情况及已知限制。
2. SBA写请求从DMI到目标总线的请求接受、ready/grant、error和commit反馈如何观测；`SBCS`中哪些状态只反映调试器请求完成。
3. V4.4成功记录所对应的芯片批次/封装/目标板，与当前样片是否相同。
4. 供应商认可的CPU-store或RAM自检方法；如需要内部波形/ATE访问，明确测试入口与可恢复性。

这是 V7.7 阶段的历史建议，已由后续 V7.8–V8.4C 的实物结果取代。当前时钟、GPIO Pad、FIFO 与 I2C_EN 都有真实读回；下一步不是继续写这些初始化项，而是确认从机后抓一笔受限只读身份寄存器事务。Flash/NVR、reset、断电、DPC abstract write 仍不执行。

## 文件与哈希

- CPU-store Tcl：`03_experiments/bbx_v77_cpu_store.tcl`；SHA-256 `09DC818C154630F818DF390571D3CD1F159721A63801ED29A785ECC2CD968B58`。
- GPR postexec Tcl：`03_experiments/bbx_v77_progbuf_gpr.tcl`；SHA-256 `F886516C3223B412E5D606CBB84F66E1CBA37E3BE454990ACA4EB94581686CE9`。
- 一次性runner：`run_bbx_v77_cpu_store_once.py`、`run_bbx_v77_progbuf_gpr_once.py`；runner哈希记于`command.json`。
- 全部marker均保存在`markers/`；失败阶段marker没有删除、覆盖或复用。
