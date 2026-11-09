# V8.5 OLED 首帧测试结果

日期：2026-11-05（Asia/Shanghai）  
阶段：`BBX_V85_OLED_FIRST_CMD_01`  
判定：**FAIL_OR_UNKNOWN；未证明 OLED 收到命令或产生 ACK。**

## 本轮操作

用户确认 OLED 接线正确且模块已由 STM32 验证可用。V8.5 在新的 OpenOCD 会话中完成 JTAG 检查，并只执行了一次 CPU halt 请求。前置读回符合预期：IDCODE=`0x1E200A6F`、DMSTATUS=`0x00430382`、SBCS=`0x20040404`、CLKEN=`0x21`、PERI_RST=`0`、MODULE_CTRL=`0x0E`、FIFO=`0x05`、MODE=`1`、I2CM_CTRL=`0`、RAW=`0`，GPIOB Pad8/9 配置和数字输入也符合历史设置。

目标 MMIO 写入共 **5 次**，无重试：

1. ADDR `0x40002824 <- 0x3C`
2. MODULE_CTRL `0x40002800 <- 0x0F`（打开 I2C_EN）
3. TX_FIFO `0x40002808 <- 0x00`（SSD1306 command-control）
4. TX_FIFO `0x40002808 <- 0xAF`（display-on command）
5. I2CM_CTRL `0x40002828 <- 0x02`（只请求一次 STOP）

本轮不写 Flash/NVR、SRAM 或其他外设，没有软件复位、断电或 CPU resume 操作。

## 关键结果

在两个 FIFO 字节入队后：

| 寄存器 | 读值 | 解释 |
|---|---:|---|
| RAW_INTR_STA `0x40002858` | `0x00000000` | 没有记录到 NACK/仲裁/STOP 标志；不能据此认定 ACK |
| I2C_STA `0x4000283C` | `0x00000001` | I2C master WORK=1、DATA=0；控制器仍处于工作态 |
| FIFO_STA `0x4000280C` | `0x00000204` | TX_NUM=2，TX FIFO 仍有两个字节，TX_EMPTY=0 |

脚本请求一次 STOP 后，独立只读阶段 V8.5C 再次读到相同的关键状态：MODULE_CTRL=`0x0F`、ADDR=`0x3C`、FIFO=`0x204`、I2CM_CTRL=`0x02`、I2C_STA=`0x01`、RAW=`0`、GPIOB_IDR=`0x2C`。IDR 只能说明数字输入采样为高，不是示波器波形证据。

手册定义 STOP=1 时要等 TX FIFO 空才结束传输；由于 TX FIFO 仍有两个字节，虽然 STOP 位已写入，但 RAW_INTR_STA 没有 STOP 事件，master 也没有回到 idle。因此本轮没有完成 I²C 帧。**OLED 是否看到 START、地址或数据，ACK 是否发生，都未知。**

## 阶段记录

- [V8.5 原始合并日志](runs/BBX_V85_OLED_FIRST_CMD_01_20261105_153417_958354/openocd.combined.log)，SHA-256 `F38BDA79F9CACC912EA6E4555863A83A39C5AEB6046820F413BBEA47065C5735`
- [V8.5 命令与文件哈希](runs/BBX_V85_OLED_FIRST_CMD_01_20261105_153417_958354/command.json)
- [V8.5 结果 JSON](runs/BBX_V85_OLED_FIRST_CMD_01_20261105_153417_958354/result.json)
- [V8.5B 只读快照尝试](runs/BBX_V85B_OLED_POSTFAIL_RO_01_20261105_153723_642465/)，当时 CPU 已回到 running，故未读取外设状态、目标 MMIO 写入 0。
- [V8.5C 只读快照日志](runs/BBX_V85C_OLED_POSTFAIL_RO_01_20261105_153839_032052/openocd.combined.log)，SHA-256 `4C01EAD03076ADB98DCD6ACA72FDCFB118724AE28702B51E3FCBA1A99997EBFB`
- [V8.5C 结果 JSON](runs/BBX_V85C_OLED_POSTFAIL_RO_01_20261105_153839_032052/result.json)，目标 MMIO 写入 0。
- 阶段 marker 均保留，禁止复用或删除。

## 当前已知状态与停止点

最后一次读回显示 I2C_EN=1、TX FIFO 两字节未清空、MCTR STOP=1、I2CM_WORK=1。此状态可能仍未退出 master 工作态。**在确认如何安全清空/复位此控制器状态前，不再写 TX_FIFO、不发第二帧、不切地址、不改分频。** 不把这次失败自动归因为 OLED、接线或 ACK。

优先核对 ARM 参考例程的单字节发送与等待顺序，并让用户回报 V8.5 执行时 Pad8/SCL、Pad9/SDA 是否出现过波形。后续任何 FIFO 清除、I2C_EN 关闭或 PERI_RST 操作，先依据手册/ARM/RTL 做风险评估，再单独记录执行。
