# V111：基于 V110 仿真的下一轮 I²C 测试方案

## 目标

先确认 V108 可能留下的 Pad9 GPIO 状态是否已被重新上电清除，再对齐 ARM 驱动的地址/FIFO/STOP 流程，最后用最少的实物事务判断主机控制器是否从 TX FIFO 取数并把字节送到 OLED。目标依次为：实物总线出现 START 和 SCL、OLED 对地址 ACK、从机 ACK 数据；本阶段不以点亮 OLED 为验收条件。

## 已知基线与风险

- V108 最后一次状态：`PERI_CLKEN=0x1`、`PERI_RST=0`；GPIOB 初始 ODR=0、DIR=0、IDR=`0x20`、OSOD=0、AFR1=0、AFR2=0。随后 OSOD bit3 和 DIR bit3 写入成功；DIR 释放写入读回仍为 8，脚本停止。重上电后的值尚未读回。
- 因为 V108 将 PAD9 配成 GPIO 输出，而初始 AFR1/AFR2 为 0（GPIO 功能选择），实际失败可能与 GPIO/PADMUX/SBA 写行为有关；不能把该次观测直接归因于 I²C FIFO。
- 数字设计说明确认 Pad8=GPIOB2/I²C_SCL(io)、Pad9=GPIOB3/I²C_SDA(io)，I2C base `0x40002800`；ARM 样例配置 Pad8/9 为开漏 AF3。
- V110 证明 V31 behavioral mock 在自定义“两 FIFO 字节=地址+数据”约定下能产生总线波形，但该约定不等于 ARM 参考驱动，也不是真实 IP。

## 阶段 1：V109-PWR 只读上电基线（下一项实物测试）

### 执行内容

1. 建立新的只读阶段名和 marker。若该 marker 已存在，停止并换全新阶段名，不删除/复用旧 marker。
2. 确认当前 DAPLink 序列号、唯一 TAP、IDCODE=`0x1E200A6F`、DMSTATUS、SBCS；记录 CPU 状态。若 CPU running，最多一次 `halt 2000`，确认 halted 后继续；失败即停止。
3. 读取 `PERI_CLKEN=0x4002180C` 和 `PERI_RST=0x40021810` 各三次，必须各自一致。
4. 仅当 GPIO clock gate bit0=1 且复位条件允许时，读取 GPIOB ODR/DIR/IDR/OSOD/PUPD/AFR1/AFR2；不写寄存器。若 GPIO gate off，跳过 GPIO 内部寄存器。
5. 若 I²C clock gate bit5=0，不读取 I²C 内部寄存器。任何 clock/reset 采样不一致、SBA busy/error、IDCODE 不符都停止。
6. 记录示波器 CH1=Pad8/SCL、CH2=Pad9/SDA 的静态空闲电平，不驱动总线。若两线不是稳定高电平或芯片 IDR 与外部线路明显不符，停止并保留数据。

### 阶段 1 判定

- **安全基线通过：** 电源重启后相关 GPIO 状态稳定、引脚处于释放状态、空闲线高。进入离线 ARM 流程模型；这仍不代表 I²C 时钟已开启或控制器可传输。
- **GPIO 状态仍为输出/开漏拉低，或 IDR/引脚电平矛盾：** 不做 I²C 写入；优先追 GPIO/PADMUX/reset domain 与 SBA 写读回问题。
- **时钟门控/复位状态异常或采样不一致：** 立即停止，先处理时钟/复位/访问可靠性，不触碰 FIFO。

## 阶段 2：离线 ARM 风格 FIFO 事务模型（先于新的实物事务）

在 V31 之外建立独立模型/测试，不改写历史 V31 源码或结果。显式标注“ARM 软件流程行为模型，非 ASIC RTL”。

### 模型事务顺序

1. Pad 配置：Pad8/9 对应 GPIOB2/3、AF3、开漏和释放态；引脚上拉条件建模为外部上拉。
2. 外设时钟开启；检查复位释放。
3. 设置 CLK_DIV0/CLK_DIV1、MCTR、HOLD。
4. 使能 TX/RX FIFO，设置 MODE=Master。
5. 将 OLED 目标地址写入 ADDR（逻辑 7-bit 地址 `0x3C`；在实现前再核实驱动的寄存器编码，不能把总线上 8-bit 地址字节 `0x78` 误当成相同字段值）。
6. 最后设置 I2C_EN；清理/采样中断状态；向 TX FIFO 写一个负载字节。
7. 模型 master 从 FIFO 弹出字节到移位器；在 SCL 低期间设置 SDA，在 SCL 高期间从机采样；第九个时钟由从机 ACK/NACK。
8. 按 ARM 样例轮询 WORK/DATA、TX_NUM 和错误；达到其退出条件后置 STOP，再观察 WORK 清零和线路释放。

### 离线测试矩阵

| 场景 | 注入/观察 | 预期断言 |
|---|---|---|
| 正常单字节 ACK | 地址 0x3C，FIFO 放一个字节 | START；地址 8 bit；地址 ACK；数据 8 bit；数据 ACK；STOP；TX_NUM 回零；WORK 清零；SDA/SCL 释放。 |
| 地址 NACK | 从机不匹配地址 | 地址帧后 NACK；按驱动错误路径停止或发 STOP；不得假报数据 ACK。 |
| FIFO 卡一项 | TX_NUM 保持 1、WORK=1、DATA=0 | 软件超时并保留状态快照；不能误发 STOP 或报告成功。 |
| DATA 未出现但 TX_NUM=0 | 注入状态异常 | 超时/异常分支明确区分“FIFO 空”与“事务完成”。 |
| STOP 未置位 | 最后一个 FIFO 项被消费，STOP=0 | SCL 按手册描述保持低；软件置 STOP 后才生成 STOP/释放。 |
| Pad9 未释放/总线 SDA 卡低 | SDA 被外部强制低 | 不把线低误判成地址 ACK；记录无 START 或错误状态。 |

V31 现有模型没有真实分频，因此离线模型只验证事件先后关系，不能用来选择真实波特率或确定真实周期。新增结果不能覆盖 V31 历史文件。

## 阶段 3：受控单字节实物测试（阶段 1、2 通过后另行准入）

### 不变量与先决条件

- V109-PWR 只读基线通过，GPIO/PAD 状态确认安全，SDA/SCL 空闲高。
- 只用 Pad8/SCL、Pad9/SDA；示波器 CH1/CH2 与地线固定后再供电/调试，避免手持探头碰触电脑接口。
- 真实测试代码尽量由 CPU 执行，按 ARM 驱动顺序配置并把阶段码、寄存器快照写入已核实安全的 RAM 邮箱；不要让 OpenOCD 直接连发一串 FIFO/MMIO 写，避免与已知 SBA 读写不确定性混在一起。
- 若安全 SRAM 运行/邮箱地址、固件入口或 CPU 执行方式未证实，则本阶段 BLOCKED；不得为赶进度改写 Flash/NVR 或猜 RAM 地址。
- 对每个真实写入阶段单独列出允许地址和值、执行次数和风险，获得该阶段授权后才执行；出错立即停止，不复位/恢复/重试。

### 实物最小帧

- OLED 目标使用 7-bit 地址 `0x3C`。先核实本工程 ARM 驱动 ADDR 寄存器编码；线上应看到写地址字节 `0x78`，不能把 `0x78` 无条件写进地址寄存器。
- 一次只发一个 OLED 控制字节（例如 `0x00`，作为命令流控制字节）；它用于确认地址和数据阶段 ACK，不保证屏幕可见变化。
- 固件在写 FIFO 前后记录：MODULE_CTRL、CLK_DIV0/1、MODE、ADDR、MCTR、FIFO_STA、SR、RISR/RAW_INTR；轮询期间记录首次见到 WORK、DATA、TX_NUM 变化的顺序和超时快照。
- 示波器同步观察：SDA/SCL 空闲、START、地址 8 个时钟、地址 ACK、第 9 个时钟、数据 8 个时钟、数据 ACK、STOP；记录实际周期和低/高时间，不先假设频率。

### 实物结果分支

| 观测 | 首要定位方向 | 后续动作 |
|---|---|---|
| 写 FIFO 后 TX_NUM 不增 | 写入提交/时钟 gate/FIFO enable/总线访问 | 停止事务，不继续堆 FIFO；对照 CPU store 与 SBA 证据。 |
| TX_NUM=1、WORK=1、DATA=0，SCL/SDA 无活动 | 控制器启动条件、MODE/ADDR/FIFO 数据语义、I2C clock/reset 或 APB 写提交 | 保存前后状态；不要照搬 mock 的“两字节启动”假设。 |
| TX_NUM 下降但 SCL 无波形 | Pad mux、I2C 输出路由、时钟分频/控制器内部状态 | 先查 Pad8/9 AF 与波形测点。 |
| 有 SCL，SDA 没有 START/地址数据 | SDA PADMUX、开漏/方向/线路冲突 | 停止，排查引脚路由和输出使能。 |
| 地址帧完整但地址 NACK | OLED 地址/供电/从机兼容性 | 确认线上 0x78 及 ACK 位，不先判断 FIFO 故障。 |
| 地址 ACK、数据 ACK、STOP 均完整 | master→OLED 链路通过 | 再做 OLED 初始化命令序列，最后验证显示字符。 |

## 资料依据及限制

- 数字设计说明：`D:\project\RISCV-63300\_analysis\design_doc_full.txt`，I²C 4.19（MODULE_CTRL、TX_FIFO、FIFO_STA、CLK_DIV、MODE、ADDR、MCTR）及 Pad mux 约 7597–7602 行。
- ARM 样例：`D:\project\63300\CY63300_测试样例\IIC_Master.c`（Pad8/9 AF3/开漏、7-bit mode、STOP_MODE=SCL_L、状态轮询）和 `Device_lib\src\cj32l01xx_i2c.c`（MasterInit、I2C_Cmd、SetAddr、WrByte、GenerateStop）。
- V108 实物结果：`D:\Obsidian\notes\笔记\beansugar\vibe coding\memory\cy63300自动测试日志\reports_20261109_193021\CY63300_I2C_BLACKBOX\45_V108_PAD9_GPIOB3_COMPARISON_TEST_RESULT_20261109.md`。
- V110 仿真：`D:\Obsidian\notes\笔记\beansugar\vibe coding\memory\cy63300自动测试日志\reports_current\V110_RTL_I2C_FIFO_FLOW_SIMULATION\V110_RTL_I2C_FIFO_FLOW_SIMULATION.md`。

## 本计划操作边界

本报告只规划，没有连接目标、读写 MMIO、复位、resume、烧录、断电或创建/消费实物测试 marker。每个后续真实硬件操作均在单独阶段执行并保留日志。
