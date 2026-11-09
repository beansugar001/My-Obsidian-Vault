# V8.7：OLED 单像素最小化尝试结果

日期：2026-11-05（Asia/Shanghai）  
目标：按本地 STM32 OLED 初始化顺序，先单字节轮询，最终在 SSD1306 page 0 / column 0 写入一个 `1` 位。  
结果：**FAIL_OR_UNKNOWN；像素数据未发送。**

## 执行摘要

断电重插后的 V8.6N 只读状态显示控制器空闲。V8.7 用一次性、fail-fast 阶段重配 Pad 与控制器，然后只尝试 OLED 初始化的第一个控制字 `0x00`。此字写入 TX FIFO 后，40 轮轮询都读到 `FIFO_STA=0x104`（TX_NUM=1）、`I2C_STA=0x01`（WORK=1、DATA=0）、`RAW_INTR_STA=0`。脚本没有写第二字节 `0xAE`，没有写 STOP，没有进入后续 OLED 初始化，也没有发送像素数据。

随后 V8.7D 独立只读快照确认同一非空闲状态。没有执行恢复写入或复位。

## V8.7 实际操作

前置检查：DAPLink 序列号 `07000001006700343500000a4e57354aa5a5a5a597969908`；JTAG IDCODE=`0x1E200A6F`；CPU halted；DMSTATUS=`0x00430382`；SBCS=`0x20040404`；时钟=`0x21`；复位=`0`；上电后 FIFO=`0x05`、WORK=0；分频=`0x20/0x30`、MODE=1、HOLD=5；Pad 重新配置前为 GPIO 默认态。

本阶段实际目标 MMIO 写 **9 次**：

1. GPIOB ODR=`0x0C`、OSOD=`0x0C`、PUPD=`0x300`、DIR=`0x0C`、AFR1=`0x6C0`，将 Pad8/9 设为 AF3、开漏、上拉并释放；GPIO 输入读回 `0x2C`，Pad8/9 均高。
2. MODULE_CTRL=`0x0E`，设置 TX/RX FIFO；ADDR=`0x3C`；MODULE_CTRL=`0x0F`，使能控制器。
3. TX_FIFO 写入一个 OLED 命令控制字 `0x00`。

没有写第二个 FIFO 字节、MCTR/STOP、ICR、复位寄存器或任何非易失存储器；没有自动重试。

## 失败证据

### V8.7 发字节后的 40 轮状态

- `FIFO_STA=0x00000104`：TX_NUM=1，TX_EMPTY=0，RX_EMPTY=1。
- `I2C_STA=0x00000001`：I2CM_WORK=1、I2CM_DATA=0。
- `RAW_INTR_STA=0x00000000`：未见 NACK、仲裁、地址错误或 STOP 标志。
- 脚本停止点：`V87_TX_BYTE_DRAIN_TIMEOUT label=INIT_CMD_00_AE_CONTROL`。
- 目标写入 9 次；`PIXEL_FRAME_COMPLETE=0`。
- 原始日志：[`openocd.combined.log`](runs/BBX_V87_OLED_ONE_PIXEL_FAILFAST_01_20261105_195027_028716/openocd.combined.log)，SHA256 `7CB93BD9B5661615736CEBFEFC5F6C8E0E750CDA67DEEC98406B6A8043FFC4BE`。

### V8.7D 独立只读现场

- IDCODE=`0x1E200A6F`、DMSTATUS=`0x00430382`、SBCS=`0x20040404`。
- CLKEN=`0x21`、RST=`0`、MODULE=`0x0F`、FIFO=`0x104`、DIV0/1=`0x20/0x30`、MODE=`1`、ADDR=`0x3C`、MCTR=`0`、HOLD=`5`、STA=`1`、RAW=`0`、GPIOB_IDR=`0x2C`。
- 本阶段目标 MMIO 写入 0 次，结果 `READONLY_I2C_STATE_NOT_IDLE`。
- 原始日志：[`openocd.combined.log`](runs/BBX_V87D_POST_PIXEL_STALL_READONLY_01_20261105_195218_274418/openocd.combined.log)，SHA256 `7E3871B9E588FE6B64B7295C54E67B2699241F6E69403529235F886F9825BFE2`。

## 根因判断更新

V8.6K 曾一次写入 `0x00`、`0xAE` 后停在 TX_NUM=1；V8.7 现在证明，即使 FIFO 里只有一个 `0x00` 控制字，仍会停在相同 `TX_NUM=1 / WORK=1 / DATA=0 / RAW=0` 状态。因此“只因批量写入两个字节造成 FIFO 时序问题”不再是充分解释。

当前更可能卡在控制器从 FIFO 取字后的启动/反馈阶段（例如 START/地址阶段或 I²C pad 输入反馈/时序），但**没有 SDA/SCL 波形，不能确定线路上是否出现 START、地址或 ACK，也不能据此判定 OLED 或芯片 IP 损坏**。寄存器读回与 RAW=0 不能代替波形证据。

## 当前状态与停止决定

- 当前控制器仍非 idle：TX FIFO 有 1 字、WORK=1。
- **现在不要补发 `0xAE`、不要写 STOP、不要重复本阶段，也不要软件复位。** 之前 STOP 对留在 FIFO 中的字没有清除效果，软件复位解除也曾失败。
- 若要清掉这次挂起状态，完整断电重上电已在 V8.6M/N 证明能清 FIFO/WORK；重上电后再做只读 idle 基线。
- 下一次真正有区分度的工作不是重放初始化序列，而是取得流片版控制器的 START/ADDR/feedback-delay 说明，或使用不会让探头靠近电脑主板的隔离式逻辑分析/固定夹具观察 SDA/SCL。确认事务启动方式后，再设计一个新的单次 OLED 事务阶段。

## 来源与可复现文件

- OLED 初始化依据：`D:\project\stm32\4-1oled\Hardware\OLED.c`，其中 `OLED_Init()` 为 271–320 行；命令帧为 73–80 行，数据帧为 87–94 行。此示例不检查 ACK，故只用其命令序列，不将它当作成功证据。
- V8.7 执行器：[`run_bbx_v87_oled_one_pixel_once.py`](run_bbx_v87_oled_one_pixel_once.py)；Tcl：[`bbx_v87_oled_one_pixel.tcl`](03_experiments/bbx_v87_oled_one_pixel.tcl)。阶段 marker 已消费。
