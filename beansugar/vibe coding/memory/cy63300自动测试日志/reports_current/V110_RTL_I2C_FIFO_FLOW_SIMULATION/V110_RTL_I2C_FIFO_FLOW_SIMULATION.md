# V110：I²C FIFO→从机事务流程仿真记录

## 结论

已在本机使用 Icarus Verilog 12.0 重新编译并运行现有 V31 Testbench，A–G 用例全部通过，日志出现 `V31_ALL_CASES_PASS`。成功事务的 VCD 显示模型接受两个 FIFO 字节后发出 START，依次移出 `0x78` 地址字节和 `0xA5` 数据字节，模型从机对两个字节 ACK，并在约 6.715 µs 观察到 STOP。

但这只是**当前 behavioral mock 的自洽流程**，不能证明真实 CY63300 硅片按相同顺序、周期或 FIFO 消费机制工作。模型启动事务时就将 `fifo_count` 清零，随后从 `address_byte/payload_byte` 暂存寄存器送入移位器；它没有实现真实 FIFO 每字节 pop/ready 握手。并且模型把第一个 FIFO 字节当地址，ARM 驱动则先设置 ADDR，再将负载写入 FIFO。仿真结果因此揭示了模型与参考软件流程的差距，而不是芯片根因。

## 执行过程与结果

- 原工程只读运行：`D:\project\RISCV-63300\恢复jtag后\cy63300_v31_i2c`。仿真器输出和 VCD 写入工作区 `C:\Users\24796\Documents\组\V109_v31_sim`，未改动 D 盘原工程文件。
- 仿真器：Icarus Verilog 12.0（`D:\project\tools\iverilog-msys2-v12\ucrt64\bin`）。调用时将其 `ucrt64\bin` 加入进程 PATH，以解析随工具提供的运行库。
- 编译 top：`tb_v31`；来源包括 `tb_v31.sv`、`i2c_slave_bfm.sv`、JTAG DM、SBA engine、I²C behavioral model 和参考 RIB/RAM/握手模块。
- 初次运行遇到 VCD 输出路径要求 `out/v31.vcd`，只调整了工作区输出目录结构后重新运行；未修改 RTL/Testbench。最终编译成功、仿真退出码 0。
- PASS 项：DM/Halt 读路径、DMI/SBA RAM 事务、CPU 仲裁模型、时钟门控、模拟 START/地址 ACK/数据 ACK/STOP、无从机 NACK、SDA 卡低检测。
- 原始文件：`compile.log`、`simulation.log`、`out/v31.vcd`，均与本报告一起归档。

## 成功用例的 FIFO 和总线时间线

VCD 时间单位为 1 ps。该 testbench 的主时钟周期为 10 ns。下表是 VCD 中第一次从机 ACK 成功的用例 E；时间仅描述这个模拟模型，不是芯片时序。

| 时间 | 模型事件 | 含义 |
|---:|---|---|
| 5.825 µs | `fifo_count=1` | 第一个 FIFO 写被模型存入 `address_byte`（数据为 `0x78`）。 |
| 6.115 µs | `fifo_count=2` | 第二个 FIFO 写被存入 `payload_byte`（数据为 `0xA5`）。 |
| 6.125 µs | FSM 进入 START，`fifo_count=0` | 模型以“两个字节都到齐”为启动条件，并在事务真正移位前立即清零计数。 |
| 6.135 µs | SDA 拉低、START 计数加一 | START 条件：SCL 高时 SDA 高→低。 |
| 6.145–6.375 µs | 第一个 8-bit 字节移位 | `address_byte=0x78`，MSB first；模型从机在 SCL 上升沿采样。 |
| 6.385–6.405 µs | 地址 ACK | BFM 识别 `0x78`（7-bit `0x3C` + W），在 ACK 位拉低 SDA；master 模型看到 SDA=0，ACK 计数加一。 |
| 6.415–6.645 µs | 第二个 8-bit 字节移位 | `payload_byte=0xA5`，MSB first。 |
| 6.655–6.675 µs | 数据 ACK、从机记录数据 | `last_slave_payload` 在 6.675 µs 变为 `0xA5`，ACK 计数增至 2。 |
| 6.685–6.715 µs | STOP | 模型拉低 SCL、拉低 SDA，再释放 SCL、释放 SDA；STOP 计数加一。 |

### “从机怎样取得 FIFO 数据”在当前模型里的答案

1. testbench 通过 DMI/SBA 总线任务向 `0x40002808` 连续写 `0x78`、`0xA5`。
2. 模型分别把字节存进 `address_byte` 和 `payload_byte`，增加 `fifo_count`。
3. 当 `enabled && fifo_count==2`，模型取出这两个暂存字节并启动发送；没有真实的从机直接读取 FIFO。真实系统中 I²C master 控制器应从自身 TX FIFO 取字节，通过 SDA 发送；OLED 从机只从 SDA/SCL 接收串行帧，不会访问 master 的 FIFO。
4. BFM 仅在 SCL 上升沿采样 SDA，并在第九个时钟位拉低 SDA 表示 ACK。地址比较硬编码为 `0x78`；接着记录一个数据字节。
5. 因为模型在启动时就将 FIFO 计数置零，“FIFO empty”表示模型开始事务，不表示移位器已实际消费全部内容。这无法模拟“队列中仍有 1 字节、WORK=1、DATA=0”的硬件卡点。

## 与 ARM 代码和数字设计说明的对照

- 数字设计说明定义 TX_FIFO 为写入数据入口，FIFO_STA 的 TX_NUM 为当前 TX FIFO 字数，并给出 I²C 分频公式；但没有描述一个等价于此 mock 的“两次 FIFO 写入组成地址+数据”的硬件规则。手册还定义 TX_FIFO 写数据可带 R/W_CONTROL/RESTART 位，但 master 目标地址寄存器的描述存在歧义。
- ARM `I2C_MasterInit()` 开启 I²C 外设时钟后配置 CLK_DIV0/1、MCTR、HOLD、TX/RX FIFO，再选择 Master mode。`I2C_Cmd(ENABLE)` 单独开启 I2C_EN；`I2C_SetAddr()` 写 ADDR；`I2C_WrByte()` 仅等待 TX FIFO 未满后将数据写 FIFO。
- ARM 单字节样例在 TX_FIFO 放的是数据字节，先记录 DATA/WORK 与 TX_NUM；在观察到 DATA 且 TX_NUM=0 后，再置 MCTR.STOP 产生 STOP。STOP=0 且 FIFO 空时保持 SCL low，与手册描述一致。
- V31 model 的 testbench 则写 `CLK_DIV0=2`、`CLK_DIV1=2`、MODE=Master、MCTR.STOP=1、MODULE_CTRL=`0x0D`，再向 FIFO 写 `0x78` 与 `0xA5`。它在 CLK_DIV 数值上没有生成真实分频波形，因此 VCD 的短周期不具备波特率含义。
- 所以，V31 的成功模型用例与 ARM 的地址装载方式和 STOP 控制顺序不同。下轮仿真应新增一个**ARM 风格参考驱动模型/事务测试**：ADD R 写目标地址，FIFO 只写 payload，按 DATA、TX_NUM、STOP、WORK 逐步检查；同时单独建一个“TX_NUM=1、WORK=1、DATA=0”故障注入场景，用于验证软件超时快照。它仍然是协议/控制流程模型，不能代替真实 IP。

## 现有 RTL 是否支持当前问题仿真

| 问题 | 现有模型能否验证 | 原因 |
|---|---|---|
| 在模型假设下从 FIFO 发送字节、从机 ACK/NACK | 能 | V31 mock/BFM 已执行通过。 |
| ARM 风格“ADDR 配地址、TX_FIFO 放数据、DATA/TX_NUM 后 STOP”流程 | 当前版本不能直接验证 | 现有 mock 用 FIFO 第 1 字节作地址、第 2 字节作数据，并忽略 `addr_reg` 的事务语义。可新增行为级模型后做软件逻辑回归。 |
| 真实 CY63300 FIFO 如何 pop、DATA/WORK 如何产生、真实 SCL 分频与 HOLD 时序 | 不能 | 没有真实 I²C IP RTL；模型自身说明不实现 divider 时序。 |
| V108 GPIOB3 DIR 写 `0` 后读回仍为 `8`、Pad9 IDR 与外部线电平不一致 | 不能 | 当前平台没有真实 GPIO/PADMUX/pad、电气及相关 APB/时钟复位集成路径。 |
| OLED 是否接收显示“1”或“Hello” | 不能 | BFM 不是 OLED/SSD1306 模型，只 ACK 一个固定地址并记录数据字节。 |

## 建议后续顺序

1. **先扩展仿真，不先碰芯片：** 建 ARM 风格的软件事务测试，分阶段检查时钟、分频、MCTR/HOLD、FIFO enable、MODE、ADDR、I2C_EN、单字节写入、DATA/TX_NUM、STOP 和 WORK 清零；每一步将寄存器写与序列化波形分开断言。
2. **给 FIFO 加可观察的真实语义边界：** 模型记录 push/pop 时刻、FIFO 深度、取数/移位完成、DATA/WORK 状态。增加 FIFO 保留 1 项、仅地址 ACK、数据 NACK、STOP 未置位、总线卡低等场景。明确这些是人为规定的行为假设。
3. **先跑理想 ARM 风格用例，再跑卡点注入用例：** 仿真只回答状态机/软件顺序是否自洽，以及观测寄存器组合是否会导致软件等待死锁。
4. **随后重新评估硬件：** V108 方向释放失败仍须由重上电后的新只读快照确认已经复位；未证实 GPIO/PAD 状态安全前，不通过实物写 FIFO。实物测试应采集 SDA/SCL 波形和 TX_NUM/SR/RISR 时间序列。
5. 真正硅片内部 FIFO pop、APB bridge accept、控制器状态机握手若没有暴露到寄存器/引脚，需供应商提供内部 trace/真实 IP RTL 或总线握手波形；行为模型无法给出此类证据。

## 产物和 SHA256

| 产物 | SHA256 |
|---|---|
| `compile.log` | `2D249DC5AFEE22E778B3A5FB061A0D53B31545EF204899005324ED96944AAA75` |
| `simulation.log` | `F9AF002C155E689CDB0188C4080EDC18E05B8EAADDB40EE58EF89C2F2F23D620` |
| `out/v31.vcd` | `CFB527D547293C7825E05BC8F084C399F74DF1B0388D1B4C5FF2AA432882C7D7` |
| `rtl/i2c_behavioral_mmio.v`（输入源） | `B004209CBE81B106ECA7A1B7EBBE6890A5BAF550BC88AEA2B493054A5200F7EC` |
| `tb/tb_v31.sv`（输入源） | `14531E6AE72C2C2811C2358739FEEE0B6805C7BFA50AED505B4E24A05732CEED` |
| `tb/i2c_slave_bfm.sv`（输入源） | `56E76E0C231405509CD24E0FB1673D1C43A65617304CB59BC8FEAF5328F26CDE` |

仿真文件归档目录：`D:\Obsidian\notes\笔记\beansugar\vibe coding\memory\cy63300自动测试日志\reports_current\V110_RTL_I2C_FIFO_FLOW_SIMULATION`。

本轮仅离线编译、仿真及波形分析；没有访问真实目标芯片、没有发出硬件 MMIO 写入。
