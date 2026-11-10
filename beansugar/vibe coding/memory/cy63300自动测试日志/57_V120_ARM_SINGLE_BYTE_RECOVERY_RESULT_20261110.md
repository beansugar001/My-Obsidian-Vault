# V120 ARM 单字节保护测试结果与下一步

日期：2026-11-10（Asia/Shanghai）

## 结论

本轮没有尝试点亮 OLED。OLED 命令探测阶段中，控制器进入 `WORK=1`，TX FIFO 留有 1 字，RAW_INTR=0；一次 MCTR STOP 请求未能让它回到空闲。随后 V120 只执行了 I²C 软复位断言/释放各一次，发现释放写入后 `PERI_RST` 仍读为 `0x20`。因而 V120 在前置状态恢复阶段停止：**ARM 单字节数据 0xA5 没有写入 FIFO，控制器配置没有继续，未发生重试。**

当前建议先重新给目标板断电再上电（重新插拔 Type-C），让 `PERI_RST` 回到 0；在新的只读基线确认前，不继续配置或写 TX FIFO。

## 手册与 ARM 流程核对

- 数字设计说明 §4.19.9：`I2CM_CTRL.STOP=0` 表示 TX FIFO 空时保持 SCL 低；`STOP=1` 表示在 TX FIFO 空时终止传输并产生 STOP。因此 TX FIFO 仍有 1 字时写 STOP，不能视为 FIFO 清除或可靠的取消操作。
- ARM `IIC_Master.c::I2C_Master_SendByte()`：每次只写一个 TX FIFO 数据字节；轮询 `I2CM_DATA`、`TX_NUM==0` 以及 NACK/仲裁/地址错误；达到传输里程碑后才请求 STOP。这个状态机用于 V120 设计，但因软复位释放失败，尚未执行到发字节步骤。
- ARM 驱动 `Peri_SoftReset()` 对 reset 位做置位、清位两次写。RISC-V 数字设计手册把 I²C reset 定义为 `PERI_RST[5]`；ARM 头文件位号与手册不一致，本轮只按手册 bit5 操作。
- 参考 V33 RTL 是行为模型，不能作为流片 I²C 实现的证明。本轮没有用它推断实物行为。
- OLED 文档/STM32 例程：OLED 为 4 线 I²C，7 位地址 0x3C；命令传输应为控制字节 0x00 加命令字节（例如 0xAE）。当前失败发生在任何有效 OLED 命令完成之前。

## 本轮硬件证据

| 项目 | 结果 |
|---|---|
| JTAG TAP / IDCODE | PASS：唯一 `riscv.cpu`，`0x1E200A6F` |
| DAPLink | PASS：序列号 `07000001006700343500000a4e57354aa5a5a5a597969908` |
| CPU / DMSTATUS | PASS：一次 halt 后 halted；DMSTATUS `0x00430382` |
| 初始 SBCS | `0x20040404`，无 busy/error |
| I²C 时钟 / 复位 | CLKEN `0x21`；PERI_RST 初始 `0x00` |
| 卡住前事务状态 | FIFO_STA `0x00000104`（TX_NUM=1、RX_EMPTY=1）；I2C_STA `0x1`（WORK=1、DATA=0）；RAW_INTR `0x0`；GPIOB_IDR `0x2C`（Pad8/9 采样高） |
| 软复位 assert | 写 `0x40021810 <- 0x20`，回读 `0x20` |
| 软复位 release | 写 `0x40021810 <- 0x00`，回读仍为 `0x20`；复位未被确认释放 |
| V120 控制器重配置 / FIFO 字节 | 均未执行；FIFO_DATA_WRITES=0 |
| V120 stage 状态 | FAIL_OR_UNKNOWN；TARGET_WRITES=2；RESET_PULSES=1；没有 reset/resume/Flash/NVR 操作 |

历史 V86（2026-11-05）也记录了 `PERI_RST` 置 0 后仍读到 `0x20`，随后模块/FIFO状态读数异常；该阶段被判定 FAIL，后续是重新上电后另开阶段确认空闲。它与本轮结果一致，说明软件复位“释放”目前没有可靠实物证据，不能把它当作自动恢复手段。

## 日志与哈希

最近 OLED 命令阶段目录：
`C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX\runs_local_i2c_next\BBX_OLED_CMD_AE_ACK_PROBE_20261110_01_20261110_181845_062839`

- combined log SHA256：`5D7ABD9910766831AEEC68D1E0B93308B0F085E2C204AAE0F54657C30DD2188A`
- stderr log SHA256：`388ED78B9FD3762CF869B8572B276C4814C4D95BC7909D5DF2E4B89731FCC0B4`

V120 软复位/单字节阶段目录：
`C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX\runs_local_i2c_next\BBX_I2C_ARM_ONE_BYTE_RECOVERY_20261110_01_20261110_183359_394131`

- combined log SHA256：`44DCF784DE3ECE9097A9DFBF0D2E905C69E5962AC5ACBB3528037A62DA0B5383`
- stderr log SHA256：`FBA54975F19C7BC521A7DC6BBB0EC3238FB3483E3C9EC2BBFFC0901D48910701`
- V120 marker：`markers\BBX_I2C_ARM_ONE_BYTE_RECOVERY_20261110_01.attempted.json`（保留，不重用）

## 下一步测试计划

1. 目标板重新断电上电后，建立全新只读阶段：检查 IDCODE、DMSTATUS、SBCS、PERI_CLKEN、PERI_RST、MODULE_CTRL、FIFO_STA、I2C_STA、RAW_INTR。不要先发 FIFO 字节。
2. 只有 `PERI_RST[5]=0`、时钟开启、FIFO 空、WORK=0、GPIO Pad8/9 采样高时，才配置控制器。每个寄存器写后独立读回；任一不符立即停。
3. 用 ARM 轮询法做一个数据字节试验：最多向 TX_FIFO 写一个 `0xA5`，只在 `DATA=1` 且 `TX_NUM=0` 后请求 STOP。固定短超时；未空时不追加字节、不发 STOP、不自动重试。若再次卡住，采样现场并结束本阶段；软复位释放不可靠时由用户重新断电上电恢复。
4. 只有单字节传输成功且总线/错误状态合理后，才单独做 OLED 命令帧 `0x00,0xAE`，再分阶段执行 OLED 初始化与 Hello 文本。
5. 后续实物验收仍需示波器/逻辑分析仪确认 START、地址 0x78、ACK、控制字节、命令和 STOP。寄存器状态无法替代总线波形。

## 风险控制改进

- 把“开始事务前 FIFO 空且 WORK=0”作为硬门禁。
- 每次事务只允许一个字节或一个明确的完整帧；使用定时轮询并记录 FIFO、WORK、DATA、RAW_INTR。
- `TX_NUM!=0` 时禁止追加 FIFO 写入及 STOP 写入；STOP 只在 TX_NUM=0 后请求。
- 在重试前必须先恢复并证明 `PERI_RST=0`、FIFO empty、WORK=0；当前证据不支持靠向 `PERI_RST` 写 0 自动释放复位。
- 每一轮使用新的阶段名与 marker，失败证据保留，不重复运行旧阶段。
