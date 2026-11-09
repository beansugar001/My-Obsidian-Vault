# V109 OLED/I²C 黑盒测试进展：FIFO 卡住与复位状态

日期：2026-11-09（Asia/Shanghai）  
目标：在已确认 Pad8/Pad9、时钟和控制器基线后，找出 OLED 首字节不能完成的原因。

## 结论

首个 OLED 控制字节已进入 TX FIFO，但控制器没有消耗它，状态停在 `I2CM_WORK=1`。随后 V109G 按 RISC-V 数字设计说明对 `PERI_RST[5]` 做了一次断言/释放；断言读回 `0x20`，释放后仍读回 `0x20`。V109H 独立只读复核又连续三次读到 `0x20`。因此目前 I²C 外设处于复位使能状态，不能继续发送事务，也不能据此判断“复位后 FIFO 问题已解决”。

## 关键证据

| 阶段 | 结果 | 目标 MMIO 写入 | 说明 |
|---|---|---:|---|
| V109E | `MODULE_CTRL` 写 `0xD` 后读 `0xF` | 1 | 实际 bit0/bit2/bit3 均为 1；多出的 bit1 是保留位读回 1，旧检查器误判。 |
| V109E2 | `MODULE_CTRL=0xF`，FIFO 空、STATUS=0、GPIO IDR=`0x2C` | 0 | 独立只读确认控制器启用且总线空闲。 |
| V109F | 写一个 OLED 控制字节 `0x00` 到 TX FIFO | 1 | 约 200 ms 后 `STATUS=1`、`FIFO_STA=0x104`、`RAW_INTR=0`、Pad8/9 仍读高；字节未消耗，没有 STOP/NACK。 |
| V109G | 对 `PERI_RST` 写 `0x20`，随后写 `0x00` | 2 | 断言读回 `0x20`；释放写后读回仍为 `0x20`，阶段停止。 |
| V109H | `PERI_RST` 独立读取三次 | 0 | 三次均为 `0x20`；DMSTATUS=`0x00430382`，SBCS=`0x20040404`，无 JTAG/SBA 报错。 |

### 复位位定义差异

- RISC-V《CY63300 数字电路设计说明》寄存器表 `PERI_RST[5]` 标注 `I2c_sofrst`，`1` 为 I²C soft reset enable，`0` 为 disable。已保存的文档摘录见 `CY63300_AUTO_TEST/snapshots/digital_design_excerpts.txt`，PERI_RST 表约在摘录 138 行起、I²C 项约 218 行。
- ARM `cj32l01xx.h` 将 `SYSCTRL_I2C_SOFT_RST_Pos` 定义为 2；其同一头文件将 bit5 定义为 `SINKC_SOFT_RST`。`cj32l01xx_rcc.h` 也用 `I2C_Soft_Rst = 1<<2`。`cj32l01xx_rcc.c` 对外设复位采用 `PERI_SOFT_RST |= periph;` 随后 `&= ~periph;`。
- 这是版本/实现差异的重要证据。真实 RISC-V 芯片本轮按 RISC-V 设计说明 bit5 操作，不能把 ARM 的 bit2 直接套用。由于 RISC-V 手册明确 bit5 是 I²C，而此位读回依然置位，当前最直接的状态是 I²C 仍保持复位；写零未见效果，写事务是否真正到达寄存器需进一步辨别。

## 当前芯片已知状态

- `PERI_CLKEN=0x21`：GPIO 与 I²C 时钟位已开启。
- `PERI_RST=0x20`：按 RISC-V 设计说明解释为 I²C 软复位仍开启。
- GPIOB Pad8/Pad9 仍配置为 AF3、开漏释放；最后一次已知 IDR=`0x2C`，两线采样为高。
- V109F 之后 I²C FIFO/STATUS 读数是复位前的 `MODULE_CTRL=0xF`、`FIFO_STA=0x104`、`STATUS=1`。V109G 试图复位，但其释放失败；不得将复位前后寄存器快照混为同一状态。
- hart halted，DMSTATUS=`0x00430382`；V109H SBCS=`0x20040404`，未见 busy/error。
- 不应继续写 FIFO 或发送 OLED 数据，直到 `PERI_RST[5]` 被可靠清零并且寄存器读回稳定。

## 根因判断（证据分层）

1. **已证实的直接阻断状态**：当前 `PERI_RST[5]=1`。依照 RISC-V 数字设计说明，这使 I²C 保持软复位。
2. **未证实的起始根因**：V109F 传输前复位寄存器是 0，且控制器运行状态显示 WORK；所以该复位状态是 V109G 之后出现，不能解释 V109F 之前 FIFO 卡住的起因。
3. **V109F 的初始故障仍未定位**：可能涉及控制器时序/模式/START 触发条件、目标地址和 FIFO 消费路径，或者写入/状态反馈路径。`IDR=0x2C` 只说明芯片 GPIO 输入缓冲采样高，不证明控制器实际驱动了 SCL/SDA 波形，也不证明 OLED ACK。
4. **释放失败含义未知**：`SBCS` 无错误和 DMI 命令返回不等于 APB 写提交；V109G 的目标寄存器读回仍为 `0x20`，所以清零没有得到确认。

## 下一步门槛

1. **暂停 I²C MMIO 配置与 FIFO 写入。** 当前先恢复 `PERI_RST[5]` 到 0。
2. 由于 V109G 已有一次清零失败，下一次不应在同一会话里继续试写或重试。最安全的恢复办法是让目标完全掉电后重新上电，以硬件 POR 清除软复位寄存器；如需要用户操作，明确告知先断开板上 Type-C/供电、等待电源指示熄灭，再重新供电。重新上电后只读核对 CLKEN/RST，不假设其它易失寄存器保留。
3. 如果完全掉电重上电后 `PERI_RST` 仍为 `0x20`，停止 I²C 测试，转向 SYSCTRL 写路径验证或向芯片设计/FAE 确认 RISC-V 版复位位映射及写属性。不得改写 ARM bit2 来“碰碰运气”。
4. 只有确认 `PERI_RST[5]=0` 稳定后，才恢复时钟、Pad 配置、I²C 配置，再一次性重发一字节；捕获 SCL/SDA 或检查 STATUS/FIFO/RAW_INTR，避免直接跳到 OLED 初始化脚本。

## 可复核原始证据

本阶段各 OpenOCD 日志、命令行、marker、脚本、SHA256 应完整保存在对应 `runs_local_v109` 目录中，并同步到用户指定的 `cy63300自动测试日志` 目录。V109H 日志合并 SHA256：`6D7B7641438602B102872C7428333CD79FC3A90BC9E9FADF0E7FC8CDD62B6EA1`。

