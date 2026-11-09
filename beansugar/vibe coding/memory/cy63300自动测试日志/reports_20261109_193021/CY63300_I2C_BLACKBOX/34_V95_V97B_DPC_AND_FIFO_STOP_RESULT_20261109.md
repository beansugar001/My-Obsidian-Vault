# V95–V97B：DPC 写路径与 ARM 超时 STOP 对照结果

日期：2026-11-09（Asia/Shanghai）  
目标：解释 CPU 从 RAM 执行失败，并验证 ARM 发送函数中“FIFO 卡住后仍发 STOP”的处理是否能解除 CY 控制器卡点。

## 结论

1. **CPU 执行备用路径仍未打通。** V95 抽象 DPC 写命令无 ABSTRACTCS 错误，但把 DPC 写成 `0x20008000` 后读回仍为 `0x2C006DD2`；随后将原值写回并读回一致。V93 的 `resume 0x20008000` 也因 PC 回读仍为 `0x2C006DD2` 失败。参考 `jtag_dm.v` 中明确把 DPC 写请求转成 `dm_reset_req`，没有 DPC 寄存器写入分支；这是解释线索，不是流片 ASIC 的证明。
2. **当前 I²C 阻塞已被收窄到事务状态机未推进。** V96 的事务前快照全部符合准备条件。V97B 只向 TX FIFO 写一次 `0x00`，等待 40 个有限采样后仍 `TX_NUM=1 / STA=0x01 / RAW=0`、从未观察到 DATA；之后按 ARM 超时路径只写一次 MCTR.STOP=1，寄存器回读为 `0x02`，再观察 40 次仍为同一状态。
3. **这不是“OpenOCD/SBA 写没有落到寄存器”的简单解释。** FIFO 写的副作用体现在 `FIFO_STA=0x104`，STOP 位也读回 `MCTR=0x02`；但这些只证明 FIFO/控制寄存器状态可见，不能证明线上出现 START、SCL/SDA 时钟或 OLED ACK。
4. 当前控制器最后状态是 **FIFO 非空、WORK=1、STOP 模式已置位**。本轮未复位、未 resume、未断电、未重试。此时禁止继续往 FIFO 加字节或再次写 STOP。

## 实物证据

| 阶段 | 操作 | 结果 | 证据 |
|---|---|---|---|
| V93.03 | 装载并校验 36-byte SRAM canary；尝试从 `0x20008000` resume；随后恢复被覆盖 SRAM | OpenOCD 报 PC 写入回读 `0x2C006DD2`，邮箱未改变；代码区和邮箱恢复通过 | `runs/BBX_V93_RAM_EXEC_CANARY_*/openocd.combined.log`；SHA256 `B990D795FEFD0E39406BBB4DD7E081AC1ACF389B18133FF6D8729FC9F548862E`；报告 `32_V93_RAM_EXEC_CANARY_RESULT_20261109.md` |
| V94 | 独立只读核对 DPC/DCSR 与 I²C | DPC 两次=`0x2C006DD2`，DCSR 两次=`0xC0`；I²C FIFO 空、WORK=0 | `runs/BBX_V94_POST_RESUME_READONLY_*/openocd.combined.log`；SHA256 `B4182D987AE0F3566FFBC7EEBB6D1D0DB85D1C538FF4E58D7ED89FC0FB5DD05A` |
| V95 | 抽象写 DPC=`0x20008000`、读回，再恢复 DPC 原值 | 测试值不可见；原值恢复读回一致；ABSTRACTCS=`0x01000003`，SBCS=`0x20040404` | `runs/BBX_V95_DPC_WRITE_RESTORE_01_20261109_152152_207783/openocd.combined.log`；SHA256 `B19B1A43C886822BAD0F616F91090BC0B10D6DFCCE6B2B09AFA3E2577DC34FDF` |
| V96 | V95 后独立只读快照；一次 halt | DPC/DCSR 稳定；CLKEN=`0x21`、RST=0、MODULE=`0x0F`、FIFO=`0x05`、DIV0/1=`0x3E7`、ADDR=`0x3C`、MCTR=0、STA/RAW=0；GPIO Pad8/9 AF3、OD、上拉、IDR 高 | `runs/BBX_V96_POST_V95_READONLY_01_20261109_152518_541465/openocd.combined.log`；SHA256 `39E38BFBE5076C03EDACE11DB843D149CAFB4233028AC3A3540CBF2F87E733EF` |
| V97-01 | Tcl 启动 | Tcl 在第 84 行解析失败，未初始化目标、目标写 0 次；marker 保留 | `runs/BBX_V97_OLED_CONTROL_STOP_PROBE_01_20261109_152918_201063/openocd.combined.log`；SHA256 `91F87EA2493711D251F5AFE4E50F5712C46A4B984ABBFFE97A26734EDB6D3176` |
| V97B-02 | 一个控制字节 + 有限轮询 + 一次 STOP | 准入通过；目标写 2 次；FIFO 不出队，STOP 后也未 idle | `runs/BBX_V97B_OLED_CONTROL_STOP_PROBE_02_20261109_153029_112608/openocd.combined.log`；SHA256 `1BB5B6BCE03443ABFCC4C902B8E4142EC976515510AB25E21228D1272C6A5671` |

### V97B 关键读数

- 预检：`IDCODE=0x1E200A6F`、CPU halted、`DMSTATUS=0x00430382`、`SBCS=0x20040404`。
- Pad/控制器：`CLKEN=0x21`、`RST=0`、`MODULE=0x0F`、`FIFO=0x05`、`DIV0=DIV1=0x3E7`、`MODE=1`、`ADDR=0x3C`、`MCTR=0`、`HOLD=5`、`STA=RAW=0`、`AFR1=0x6C0`、`OSOD=0x0C`、`PUPD=0x300`、`DIR=0x0C`、`IDR=0x2C`。
- 写入 1：`0x40002808 <- 0x00000000`（TX FIFO）；入队后所有前置采样中 `TX_NUM=1`、`STA=1`、`RAW=0`，`DATA_SEEN=0`。
- 写入 2：`0x40002828 <- 0x00000002`（MCTR STOP）；读回 `MCTR=0x2`。其后 40 个样本仍为 `FIFO=0x104 / TX_NUM=1 / STA=1 / RAW=0`。
- 结束：`SBCS=0x20040404`、`DMSTATUS=0x00430382`、OpenOCD 完整结束；`TARGET_WRITE_COUNT=2`、`FRAME_COMPLETE=0`。
- 不能把 `RAW=0` 当成 ACK：本轮既没有 ACK/NACK 证据，也没有示波器波形证据。

## ARM 流程对照

ARM `IIC_Master.c` 的 `I2C_Master_SendByte()` 先清 STOP 位，清 Stop/NACK/Arbitration/Address Error 事件，单字节写 TX FIFO；轮询 `SR`、`RISR`、`FIFO_SR`，等待错误或 `DATA_seen && TX_NUM==0`；成功时发 STOP，超时时也发 STOP，然后等待 `WORK==0`。CY V97B 对当前已知空闲基线执行了等价的“FIFO 入队—有界轮询—超时 STOP”，但状态无推进。

差异边界：ARM 运行时由 CPU 连续采样，而 V97B 每次状态采样都经 JTAG/SBA，采样间隔与 CPU 不同；当前 RISC-V CPU 的 DPC/PC 运行路径未验证。ARM 工程本身也有另一个 FS routine 使用 `ADDR_10bits` 却注释/传入 7-bit 地址的矛盾；V97B 使用 `IIC_Master.c` 里明确声明的 7-bit `0x3C`，没有照搬该矛盾示例。

## 根因判断与边界

| 假设 | 当前证据 | 判断 |
|---|---|---|
| FIFO 写通道完全失效 | TX_NUM 从空变 1，FIFO 状态读到 `0x104` | 不支持“写完全未生效”；无法证明字节被主状态机取走 |
| 仅缺少 STOP 导致卡住 | 补发一次 ARM 超时 STOP 后 MCTR=2，但 TX_NUM/WORK 不变 | STOP 单独不能解除当前挂点 |
| OLED 地址/从机导致 NACK | RAW 始终 0，且 FIFO 从未出队、无 DATA；无波形 | 不能判定 ACK/NACK；当前更早卡在控制器进度/物理时钟阶段 |
| PAD/外部线路或上拉问题 | 寄存器选择与静态 IDR 正常；此前 GPIO 地址探测曾 NACK，弱偏置结果提示外部上拉能力不确定 | 仍是重要候选；软件读回不能替代对 Pad8/SCL、Pad9/SDA 的波形和电平测量 |
| I²C 流片 IP 内部状态机/时钟问题 | 配置和时钟读回通过，但 TX FIFO/WORK 无推进 | 仍可能；缺少芯片端 SCL 输出/ACK 和内部握手证据 |
| DPC/PC 写法被参考 RTL 特殊处理 | V93 PC 不变；V95 抽象 DPC 写不变；参考 RTL 有相应复位请求分支 | 能解释 RAM 执行失败的候选机制；不证明真实 ASIC RTL相同 |

### 参考 RTL 对照

本机 TinyRISC-V 参考文件：`D:\project\tools\tinyriscv-master\rtl\debug\jtag_dm.v`，SHA256：`F918FD2BF8BD700DC001894951048CFC2D1D2549B5B010D0AD953229E4A3F543`。文件第 `252` 行附近的 COMMAND 抽象寄存器写分支，对 DPC 执行 `dm_reset_req <= 1`、`dm_halt_req <= 0` 和 DMSTATUS running 更新；没有将 `data0` 写到 DPC 的逻辑。与 V95 观察相吻合，但当前不可得真实流片 Debug Module RTL，应将它标为模型解释而非最终芯片结论。

## 当前最有区分度的下一步

1. **暂不再写 I²C 寄存器。** 当前 FIFO 非空和 WORK=1，继续发数据/STOP只会增加未知状态。
2. 对目标板做一次完整断电重插，因为历史实测整板掉电能清空 FIFO/WORK；随后先跑只读快照确认 FIFO=`0x05`、STA=RAW=0。过去 I²C 软复位的解除操作有失败记录，不用软复位替代。
3. 复电后优先做一次安全外部电气观测：示波器 CH1 看 Pad8/SCL、CH2 看 Pad9/SDA，两探头地夹均接 CY63300 板 GND；10×探头、DC。先断电夹好地夹和探头，确认不会碰到电脑主板/相邻针脚，再上电。执行单次事务时重点观察 SCL 是否有脉冲、SDA 是否有 START/地址/ACK。不能安全固定探头时先不要执行该事务。
4. 若两线无波形：优先向原厂确认流片 Pad8/9 I²C 主机输出复用、Master START/FIFO 启动条件和 SCL pad enable；不要继续穷举寄存器值。
5. 若 SCL/SDA 有 START/时钟但 OLED 不 ACK：依据波形核实地址、ACK 时钟、模块绑带/线序/电平，再判线路或外设问题。
6. 在 Debug Module 的 CPU 程序计数器写路径没有厂家确认/有效替代方案前，不再尝试 SRAM resume；参考 RTL只能作为问题线索，不能作为实物根因定论。

**最终目标仍未完成：OLED 未显示 Hello。**

## 源码/手册定位

- ARM 示例 `D:\project\63300\CY63300_测试样例\IIC_Master.c`，SHA256 `50704B5EBF0D9573F8EED23566AE5235B500EFB195C0C19D72E7813F165BD4E7`：GPIO 初始化第 117 行；Master 初始化第 200 行；发送单字节与轮询/超时 STOP 第 298 行；循环调用第 626 行。
- ARM 库 `D:\project\63300\CY63300_测试样例\Device_lib\src\cj32l01xx_i2c.c`，SHA256 `CC40138708B32C56F161005912AD198D7A3C567255C3FC61FB215EC845FFA803`：`I2C_MasterInit` 第 205 行，`I2C_Cmd` 第 272 行，`I2C_WrByte` 第 325 行，`I2C_GenerateStop` 第 397 行。
- 《CY63300 数字电路设计说明》I²C 章节：`FIFO_STA`（TX_NUM）定义、`I2CM_CTRL` STOP 位定义（TX FIFO 空时保持 SCL low；STOP=1 后终止传输并生成 STOP）。本地提取见 `manual_extracts.md` 第 4.19.4、4.19.9；需通过波形确认芯片实际输出。
- TinyRISC-V 参考调试模块源码哈希和限制见上节；不是实物 RTL。
