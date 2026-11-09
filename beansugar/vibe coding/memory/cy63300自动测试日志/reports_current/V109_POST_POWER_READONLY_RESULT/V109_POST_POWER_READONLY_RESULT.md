# V109-PWR 重上电后只读快照结果

## 结论

V109-PWR 阶段**执行完成**，但这不是 I²C 功能通过：JTAG/调试访问正常，PERI_CLKEN 与 PERI_RST 稳定为 0；GPIO 和 I²C 外设时钟均关闭。因此按门控规则跳过了 GPIOB 与 I²C 内部寄存器，无法从本轮判断 Pad9 是否已恢复默认，也没有进行 I²C 事务。

## 实物采样

| 项目 | 结果 |
|---|---|
| DAPLink 序列号 | `07000001006700343500000a4e57354aa5a5a5a597969908` |
| TAP / IDCODE | 唯一 `riscv.cpu` / `0x1E200A6F` |
| hart | RV32，`misa=0x4CC0680A` |
| CPU 初态 | running；仅发出一次 `halt 2000` 后确认 halted |
| DMSTATUS | `0x00430382` |
| SBCS 预检 | `0x20040404`，无 busy/error |
| PERI_CLKEN | `0x00000000`、`0x00000000`、`0x00000000`，三次一致 |
| PERI_RST | `0x00000000`、`0x00000000`、`0x00000000`，三次一致 |
| GPIOB 寄存器 | 跳过：GPIO clock gate bit0=0 |
| I²C 内部寄存器 | 跳过：I²C clock gate bit5=0 |
| 目标 MMIO 写入 | 0 次 |
| 复位/resume/Flash/NVR/FIFO/I2C_EN | 均未执行 |

OpenOCD 使用 100 kHz 配置；host snapshot 未发现 OpenOCD/GDB 等目标调试客户端或相关端口冲突。系统中有 `Altera JTAG Server` 服务，PID 16884，监听 TCP 1309；根据既定互斥规则，该服务不单独判为 CMSIS-DAP 冲突，也未停止它。

为进行 SBA 只读采样，脚本通过 DMI 改写了调试模块 SBCS 的读取模式。初始 SBCS 为 `0x20040404`，会话结束读到 `0x20140404`；这是 Debug Module SBA 控制状态，不是目标外设 MMIO 写入。后续读脚本应自行设置读取模式并检查 SBCS。

## 判读

- 重上电后外设时钟门控回到关闭状态；这是当前读到的状态，不能推断此前 I²C 配置或 Pad9 复位是否正常。
- 由于 GPIO 时钟关闭，本轮没有读取 `GPIOB_DIR/OSOD/AFR/IDR`，所以 V108 的“Pad9 方向释放写未生效”尚未被复核。
- 由于 I²C 时钟关闭，本轮没有读取 MODULE_CTRL、FIFO_STA 或 I2C_STA；本轮也没有检验 FIFO 消费或 SDA/SCL 波形。

## 下一项最小测试

下一步需要将 GPIO 外设时钟单独打开，再只读检查 GPIOB：

`PERI_CLKEN 0x4002180C <- 0x00000001`

此值只打开 GPIO gate bit0，保留 I²C gate bit5 为 0。写入后另开只读会话检查 PERI_CLKEN、PERI_RST 和 GPIOB ODR/DIR/OSOD/PUPD/AFR/IDR；若时钟写入读回不符或状态异常即停止。**这是一笔新的目标 MMIO 写入，本轮未执行，需单独授权。**

只有 GPIO/PAD 状态检查通过后，再规划 I²C 时钟开启和 ARM 风格单字节测试；不得在本轮结果上直接开启 FIFO 或 I2C_EN。

## 运行归档

- 阶段：`BBX_V109_POST_REPOWER_READONLY_01`（marker 已创建并保留）
- 运行目录：`D:\project\RISCV-63300\CY63300_I2C_BLACKBOX\runs\BBX_V109_POST_REPOWER_READONLY_01_20261109_203316_809894`
- OpenOCD 完整日志 SHA256：`7A78F7703008D94A15629E63F9BDB02F1A8FE9D485F0F2A1A977E5C714C87887`
- stdout SHA256：`E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855`（空；本 OpenOCD 构建将消息写入 stderr）
- stderr SHA256：`31A9EF0E6FD7E98CFF247B18E653214231FC1813B9872A025D941DF4AC3C7E17`
- OpenOCD SHA256：`EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27`
- 配置 SHA256：`CB6064F0866A495C067C634FAB91C9A2084AE1805E171C6BCA5758F3A241A4A1`
- Tcl SHA256：`4F31373F9D6E4BB27A30919856F30EEE5434BD0322FC1039BC5CD749D7DAB8F0`

本轮目标 MMIO 只读共 6 笔（CLKEN 三笔、RST 三笔）；DMSTATUS/SBCS 属于独立 DMI 调试模块访问。没有目标 MMIO 写入。没有自动重试、复位、resume、断电或恢复操作。
