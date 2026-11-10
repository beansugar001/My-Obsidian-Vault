# V111：公司流程适配测试结果

日期：2026-11-10

## 结论

已按公司 `CY63300.c::I2CTest()` 的初始化次序，用 RISC-V 板的 Pad8/Pad9 复用完成配置，并尝试发送 OLED 命令帧。寄存器写入/读回应均符合预期，但 TX FIFO 再次没有排空，I2CM_WORK 保持 1，未观察到 DATA 状态或 STOP/NACK 中断。**本次没有点亮 OLED，也没有证据证明地址字节或数据到达 OLED。**

本轮在 TX FIFO 卡住后立即停止，没有请求 STOP、没有继续写 FIFO、没有软复位、没有重试。

## 分阶段结果

| 阶段 | 关键实测值 | 目标 MMIO 写次数 | 结果 |
|---|---|---:|---|
| V111A0 重新上电只读门禁 | IDCODE `0x1E200A6F`；DMSTATUS `0x00430382`；SBCS `0x20040404`；CLKEN=0、RST=0 | 0 | PASS；CPU 初始运行，本阶段 halt 一次 |
| V111A1 时钟与寄存器基线 | CLKEN=`0x21`；RST=0；MODULE_CTRL=`0x02`；FIFO=`0x05`；DIV0=`0x20`；DIV1=`0x30`；MODE=1；MCTR=0；HOLD=5；STATUS=0；RAW=0 | 1 | PASS；一次开启 GPIO/I²C 时钟，控制器是干净 idle |
| V111A2 引脚配置 | Pad8/9=GPIOB2/3 AF3 开漏；ODR/DIR/OSOD=`0x0C`；AFR1=`0x6C0`；IDR=`0x2C`（两线输入采样高） | 4 | PASS |
| V111A3 公司 MasterInit 参数 | DIV0=`0x0F`、DIV1=`0x23`、MCTR=0、HOLD=5、FIFO 使能；MODULE_CTRL=`0x0E`（I2C_EN=0）；MODE=1；FIFO=`0x05`、STATUS=0 | 6 | PASS；分频值来自公司 H/L 各减一，MCTR=0 为 7-bit/SCL_L 手动 STOP |
| V111A4 使能与地址 | MODULE_CTRL=`0x0F`；ADDR=`0x3C`；FIFO=`0x05`；STATUS=0；RAW=0；IDR=`0x2C` | 2 | PASS；按 `I2CTest()` 顺序先使能、再设地址 |
| V111A5 OLED 帧 | 向 TX FIFO 写 `0x00`、`0xAF`；60 次状态轮询最终 STATUS=`0x01`、FIFO=`0x104`（TX_NUM=1）、RAW=`0`、IDR=`0x2C`；未见 DATA 位 | 2 | FAIL/未完成；未达到发送完成条件，未发 STOP 请求 |

总计：15 次目标 MMIO 写入（另有每阶段 SBA/DMI 访问与一次性 halt）。没有 Flash/NVR、SRAM 或复位操作。OpenOCD 每阶段都检查了唯一目标、探针序列号和 SBA 状态；冲突检查未发现客户端/端口占用。

V111A5 日志中的 FIFO 数值表示还剩 1 字，不是清空；输入采样为高只能说明采样点读高，不能代替示波器证明没有窄脉冲。由于未接逻辑分析仪，本轮没有 START/ACK 的物理波形证据。

## 与公司 `I2CTest()` 的落实关系

公司函数设置 H=`0x10`、L=`0x24`，驱动写 raw DIV0=`0x0F`、DIV1=`0x23`；选择 7-bit、`STOP_MODE=SCL_L`、HOLD=5；`I2C_MasterInit()` 顺序为时钟、分频、MCTR、HOLD、FIFO、MODE；之后使能、设地址、写 FIFO。V111A3/A4/A5 按此顺序执行，地址和载荷替换为 OLED 文档中的 7-bit `0x3C`、`0x00` 控制字和 `0xAF` 显示开命令。

未照搬函数中的 PB0/PB1 AF2 推挽：RISC-V 手册和本板载板映射要求 Pad8/9=PB2/PB3 AF3 开漏。也未照搬其四次写入后立即关闭 I²C 时钟；该函数没有等待 TX 消耗或生成 STOP，不能作为完成证明。

## 根因判断更新

本轮排除了“重新上电后残留 FIFO 状态”和明显的时钟门控、GPIO PADMUX、分频/主模式、控制器未使能等初始化错误：每项均在本轮重新读回验证。问题仍集中在 TX FIFO 启动/移出阶段；但仅凭 MMIO 状态无法区分：START 未生成、PAD 输出路径未驱动、主机 IP 等待条件未满足、或 RISC-V 实际 I²C RTL 与 ARM 参考差异。

尚不能据此断言 OLED 地址错误、I²C IP 损坏或连线故障。当前实验更有力地说明：照着公司的参数和配置顺序，并没有让这颗 RISC-V 芯片的 TX FIFO 自动前进。

## 下一步

当前控制器仍在 `WORK=1` 且 TX FIFO 非空；先不要再写 FIFO 或在活动总线上改配置。需要再进行一次完整断电上电来清除现场。随后建议先用 Pad8/Pad9 做**GPIO 开漏位模拟地址 ACK 判别**：关闭 I²C 控制器、保持正确 AF/GPIO 电气设置，在已知 OLED 7-bit 地址 `0x3C` 上只发送一个地址帧并采样第九拍 ACK。它能区分“管脚/从机线路及 OLED ACK 路径可用”与“硬件 I²C 控制器 TX/START 路径卡住”。如果位模拟也无法得到 ACK，再查实际电气节点/地址绑带；如果位模拟 ACK 而硬件 I²C 仍卡住，重点转向主控制器 START/FIFO RTL 或所需控制字/握手流程。此次并未执行位模拟测试。

## 原始证据

所有阶段日志、命令、结果 JSON、唯一 marker、脚本及 SHA256 清单归档于 Obsidian `reports_current/V111_COMPANY_FLOW_TEST_20261110_1014`。各 stage 完整 OpenOCD combined log SHA256：

- V111A0：`C3370F629DAAE9C4671436F32AFF44AB995A33204910EE09A393356768CF1353`
- V111A1：`6DE2F5B95AE19CCF65238C86593420DBCBD26E64297F151DD1CB1CAC595334D4`
- V111A2：`FD5D0AD29A00445758E7149DFD73DE29AAB9464B4E607FBA4CB1C512CE1908C7`
- V111A3：`2F2E8E9C3C0299196E26ACA5FD4072A7B80D4EE517A35D046556DEFBA6A4BB12`
- V111A4：`2BFFF65B9CB8935BDA4E6019B74D04A808A1B0B87A8BCDCEE94421626AC13326`
- V111A5：`D05B44B99B0E52FB99A22E6A288891E6A72D6A8092B0CFC2EC1F767EF53C3DD5`
