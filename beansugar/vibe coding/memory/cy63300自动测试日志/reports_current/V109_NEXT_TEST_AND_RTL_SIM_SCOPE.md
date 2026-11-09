# V109：重上电后下一步测试与现有 RTL 仿真边界

## 结论摘要

1. 当前先做一个新的、独立的**只读重上电基线**，不要立即写 GPIO 或 I²C 寄存器。用户已重新上电，但这不等于已证明 GPIO 输出锁存、外设时钟/复位或 I²C 状态回到默认值。
2. V108 最关键的实物观察是：GPIOB3/Pad9 的 `DIR=0x08` 写入成功，但随后写 `DIR=0` 的独立读回仍为 `0x08`；脚本因此停止。上电后需先读取确认方向/开漏状态是否回到安全值。
3. 现有 V31/V33 RTL **能模拟一个明确简化假设下的 I²C 字节传输和总线故障**，但**不能仿真当前真实芯片 I²C 控制器故障**：模型明确标注为 behavioral mock，不是 CY63300 I²C RTL；没有 Pad mux/GPIOB3 控制器链路，也不能复现“真实寄存器写后读回不一致”这一 V108 现象。

## 证据基线

### V108 实物记录

- JTAG IDCODE `0x1E200A6F`，唯一 TAP；CPU 经一次 halt 后停住；DMSTATUS `0x00430382`、SBCS `0x20040404`。
- PERI_CLKEN=`1`（GPIO 时钟开、I²C bit5 关），PERI_RST=`0`。
- GPIOB 初读：ODR=0、DIR=0、IDR=`0x20`、OSOD=0、PUPD=0、AFR1=0、AFR2=0。CH2/SDA 空闲约 3.3V，但 PB3/Pad9 的 IDR 读为 0，存在观测不一致。
- 随后 OSOD bit3 写入读回 8，DIR bit3 写入读回 8；释放方向写 `DIR=0` 后读回仍 8。脚本按规则没有继续清 OSOD。本轮总计 3 次 GPIO 目标写，没有 I²C 控制器配置或 I²C 字节事务。
- 该证据不能说明芯片复位后仍是此状态；也不能单独区分 GPIO 写通路、寄存器语义/读回、外设复位或 Pad 映射问题。

### 数字设计说明

- I²C base `0x40002800`，寄存器章节 4.19：MODULE_CTRL offset `0x00`；TX_FIFO `0x08`；FIFO_STA `0x0C`；CLK_DIV0/1=`0x10/0x14`；MODE=`0x20`；ADDR=`0x24`；MCTR=`0x28`；HOLD=`0x38`；I2C_STA=`0x3C`。
- MODULE_CTRL：I2C_EN bit0，保留 bit1 默认读 1，TX_FIFO_EN bit2、RX_FIFO_EN bit3。CLK_DIV0/1 的分频关系为 `FSCL=FPCLK/(DIV0+DIV1+2)`。
- MCTR.STOP=0 时 TX FIFO 空会让 Master 保持 SCL low；STOP=1 时结束事务并产生 STOP。
- Pad mux 表显示 Pad8=GPIOB2/I2C_SCL(io)，Pad9=GPIOB3/I2C_SDA(io)。Pad6 的 I2C_SCL 标注为输入 `(i)`，不适合作为主机时钟输出候选。
- 文档说明 I²C 寄存器和引脚复用，但没有给出完整的主机 FIFO 帧提交/START 时序程序，因此必须从 ARM 样例参考并由实物验证。

### ARM 参考流程

- `IIC_Master.c`：GPIO 外设时钟开启；PAD8/9 即 GPIOB2/3，开漏、AF3，并设置 PUPD；初始化选择 7-bit 地址模式、STOP_MODE=SCL_L；例程将 `0x50` 作为地址字段。
- `cj32l01xx_i2c.c::I2C_MasterInit` 顺序：开启 `I2C_PCLK` → CLK_DIV0/1 写入参数减 1 → MCTR → HOLD → 同时使能 TX/RX FIFO → MODE=Master；之后由 `I2C_Cmd(ENABLE)` 单独设置 I2C_EN；`I2C_SetAddr` 依据 ADDR_MODE 写地址。
- Master 单字节样例先清 MCTR.STOP，再清中断并写 TX_FIFO，然后观察 SR、RISR、FIFO_SR；只有观察到 DATA 且 TX_NUM=0 才调用 `I2C_GenerateStop()`，随后等 WORK 清零。这解释了 ARM 文档所述一种“FIFO 空但 SCL 被保持低”的软件状态。
- 但该 STOP 逻辑只能解释达到 `TX_NUM=0` 且 DATA 已出现后的保持行为。此前 RISC-V 诊断曾看到 `TX_NUM=1 / WORK=1 / DATA=0`，属于更早的卡点，不能简单套用 ARM STOP 解决。
- ARM 当前样例头文件 `cj32l01xx_rcc.h` 的 `I2C_PCLK` 是 bit5；其他 ARM 分支宏曾出现 bit2 差异，实际迁移必须以本次审查的具体工程文件为准，不把不同分支混用。ARM 软件顺序是参考证据，不等同于该 RISC-V 流片 IP 的实测结论。

## 下一项测试：V109 只读重上电快照

### 前置与规则

- 使用新的阶段名、marker 和日志目录；V108 marker 已消费，不重用、不删除。
- 仅建立一次新的调试连接；检查当前 DAPLink 序列号、唯一 TAP/IDCODE=`0x1E200A6F`、DMSTATUS、SBCS。
- 记录 CPU 状态；若为 running，只允许按已经审查的调试流程提出一次 halt，并确认 halted；halt 失败、DM/SBA busy/error 或 IDCODE 不符时停止。
- 对 `PERI_CLKEN 0x4002180C` 和 `PERI_RST 0x40021810` 各读取三次，要求组内一致；任何不一致都停止。读取不是写入授权。
- 不执行 MMIO 写、复位、resume、Flash/NVR、FIFO、I2C_EN 或自动重试。

### 受门控的 GPIO 只读

- 只有 GPIO 时钟 gate bit0=1 且相应复位状态允许访问时，才读 GPIOB：ODR `0x40000100`、DIR `0x40000104`、IDR `0x40000150`、OSOD `0x40000158`、PUPD `0x4000015C`、AFR1 `0x40000168`、AFR2 `0x4000016C`。
- GPIO clock bit0=0 时，不把 GPIO 内部读数解释成有效状态；不为读取方便而开时钟。
- I²C clock bit5=0 时，不读取 I²C 内部寄存器；不得由其读数判断 FIFO 或控制器状态。
- 若可安全读取 Pad8/Pad9 的电平状态，记录其静态值；示波器可继续观察两线空闲电平，但本阶段不驱动总线。期望 SDA/SCL 空闲高约 3.3V，但这只是外部电平检查，不代表 I²C 控制器正常。

### 判定分支

| 结果 | 判定/下一步 |
|---|---|
| DIR、OSOD 已回默认输入/开漏安全状态，采样稳定，Pad9 IDR 与外部 SDA 电平一致 | 通过只读基线；再设计并单独授权下一阶段，优先评估 CPU 固件侧 GPIO/I²C 配置与状态邮箱，因为 V108 的 SBA 写释放失败仍未解释。不要直接开始 FIFO 事务。 |
| DIR 仍为输出或 OSOD/AFR 异常 | 停止，不再次盲写。保存状态，确认上电复位是否覆盖 GPIO 状态，再分析 reset domain 与访问路径。 |
| Pad9 IDR 与实际线路仍不一致 | 停止，先确认芯片 pad、mux、GPIO input path、测点与线路网名；当前 RTL mock 无法裁定此差异。 |
| 任一预检状态不一致、SBA 错误/忙或连接异常 | 立即停止并保留日志，不自动重试、恢复或复位。 |

## 现有 RTL 能做什么、不能做什么

### 可覆盖（抽象模型回归）

- V31 的 `i2c_behavioral_mmio.v` 可根据其自定义输入约定，模拟时钟 gate、MODULE_CTRL/MODE 配置、在 TX FIFO 收到两个字节后启动 START、地址/数据 ACK 或 NACK、STOP、SDA 卡低检测。
- `tb_v31.sv` 可回归 DMI/SBA 与该 mock 的组合路径以及已建的几个场景。V33 报告中的 PASS 是参考模型行为通过，不是芯片 IP 通过。
- 可离线扩展一个**故障注入模型**，刻意构造“FIFO 项不消耗”“DATA 不出现”“STOP 时机错误”“GPIO DIR 写入不接受”等候选状态，用于验证诊断脚本和固件状态机，但注入参数代表假设，不是芯片事实。

### 无法覆盖当前真实故障

- 目录中没有真实 CY63300 I²C 控制器 RTL；mock 文件首行也明确标为非真实 I²C RTL。
- 模型的事务在 `enabled && fifo_count==2` 时启动，并且立即把 fifo_count 清零；因此不能复现观测到的单字节留队/`TX_NUM=1` 卡住。
- 模型把第一笔 TX_FIFO 写解释为地址字节 `0x78`、第二笔解释为负载；ARM 参考代码则先通过 `I2C_SetAddr()` 写 ADDR，再把应用数据字节写 TX_FIFO。模型既不使用 `addr_reg` 生成地址帧，也不遵循 ARM 样例的软件调用接口，因此它的成功只能验证该 mock 自己定义的事务方言。
- 模型把 PAD 输出直接连到模拟器自己的 `scl_drive_low/sda_drive_low`，没有 GPIOB、PADMUX、电气 pad、芯片封装、载板、实际 APB5/桥接逻辑和板级上拉链路；不能复现 V108 的 GPIO DIR 写后读仍为 8 或 PB3 IDR 与外部电平不一致。
- BFM 注释明确说不是 OLED 模型，且硬编码按 7-bit `0x3C` 的地址字节 `0x78` 应答；不能验证 SSD1306 初始化命令、显示 RAM 或屏幕显示 “1/Hello”。
- 现有 Testbench 没有实例化完整 TinyRISC-V CPU 来执行 ARM 风格 C 驱动；主要验证 DMI/SBA 写入模型寄存器和模拟 I²C 字节流程。

**回答：** 现存 RTL 可以做“软件时序/控制逻辑 + 简化总线行为”的仿真，也可做诊断状态机故障注入；不足以对当前实物故障作真实 IP 级仿真或证明根因。要做到后一种，需要拿到真实 I²C IP、APB5/Pad mux/GPIO RTL 与时钟复位集成模型；否则应以芯片只读状态、实测 SDA/SCL 波形和厂家提供的内部提交握手/全片读出资料为证据。

## 本轮操作边界

- 本轮只有文件读取和计划编写；没有连接芯片、没有发送 MMIO、复位、resume、烧录或断电命令。
- V109 预检尚未实际运行；重上电后的硬件状态目前仍是待读回。

## 关键资料与复现指针

- 数字设计说明提取文本：`D:\project\RISCV-63300\_analysis\design_doc_full.txt`，I²C 章节约 5978–6102 行；Pad mux 表约 7597–7602、7652–7657 行。
- ARM 示例：`D:\project\63300\CY63300_测试样例\IIC_Master.c`，Pad 初始化约 112–192 行、控制器初始化约 225–265 行、单字节状态机约 300–490 行。
- ARM 驱动：`D:\project\63300\CY63300_测试样例\Device_lib\src\cj32l01xx_i2c.c`，MasterInit 205–224、I2C_Cmd 272–277、SetAddr 307–318、WrByte 325–329、GenerateStop 393–402 行。
- 当前抽象模型：`D:\project\RISCV-63300\恢复jtag后\cy63300_v31_i2c\rtl\i2c_behavioral_mmio.v`。
- Testbench：`D:\project\RISCV-63300\恢复jtag后\cy63300_v31_i2c\tb\tb_v31.sv`；简化从机 BFM：`...\tb\i2c_slave_bfm.sv`。
- V33 仿真报告：`D:\project\RISCV-63300\仿真结果\20261102_V33_DMI_I2C\README_验证结果.md`。
- V108 实物记录：`D:\Obsidian\notes\笔记\beansugar\vibe coding\memory\cy63300自动测试日志\reports_20261109_193021\CY63300_I2C_BLACKBOX\45_V108_PAD9_GPIOB3_COMPARISON_TEST_RESULT_20261109.md`。

## 关键文件 SHA256（本次审查）

| 文件 | SHA256 |
|---|---|
| design_doc_full.txt | `C8C647D443B4A1C7A0759C3CBA90E3ECF4A4362AD89953702FBDC44204D2B6A2` |
| IIC_Master.c | `50704B5EBF0D9573F8EED23566AE5235B500EFB195C0C19D72E7813F165BD4E7` |
| cj32l01xx_i2c.c | `CC40138708B32C56F161005912AD198D7A3C567255C3FC61FB215EC845FFA803` |
| cj32l01xx_rcc.h | `9275E8BE8CDECDE365E1CC7F3BA7408AA82672E19EC011DCB43667C767C344DA` |
| i2c_behavioral_mmio.v | `B004209CBE81B106ECA7A1B7EBBE6890A5BAF550BC88AEA2B493054A5200F7EC` |
| tb_v31.sv | `14531E6AE72C2C2811C2358739FEEE0B6805C7BFA50AED505B4E24A05732CEED` |
| i2c_slave_bfm.sv | `56E76E0C231405509CD24E0FB1673D1C43A65617304CB59BC8FEAF5328F26CDE` |
| V33 verification report | `9E2756FD0A458F6CADE085D22155E6C79226A8097B939EB50C65A8A9C6268CE1` |
