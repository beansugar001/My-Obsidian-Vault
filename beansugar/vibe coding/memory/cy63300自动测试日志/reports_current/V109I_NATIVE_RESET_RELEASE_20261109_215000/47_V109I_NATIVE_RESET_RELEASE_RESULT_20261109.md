# V109I：原生 OpenOCD 写路径释放 I²C 复位结果

日期：2026-11-09（Asia/Shanghai）  
阶段：`BBX_V109I_NATIVE_MWW_RESET_RELEASE_01`

## 实验目的

V109G 通过手工 DMI/SBA 序列写 `PERI_RST=0` 未清除 bit5。为区分手工 SBA 流程与目标寄存器写属性，V109I 改用 OpenOCD 原生 `mww`，在前置值严格为 `PERI_CLKEN=0x21`、`PERI_RST=0x20` 时，对 `0x40021810` 只写一次 `0x00000000`，随后用 `mdw` 独立读取三次。

## 实际结果

- JTAG TAP/IDCODE 检查通过，DAPLink 序列号匹配。
- CPU halted；DMSTATUS=`0x00430382`。
- 前置：PERI_CLKEN=`0x00000021`，PERI_RST=`0x00000020`。
- 目标写入：`0x40021810 <- 0x00000000`，执行次数 1。
- 写后独立读回三次：`0x20, 0x20, 0x20`。
- 阶段结果：`FAIL_RESET_STILL_ASSERTED`；无自动重试、无 reset/resume、无其它目标写入。
- SBCS 执行无 busy/error；日志 SHA256：`161AB87B009DB75AD5DCA760B123D21EB2E1DBB74D78C49F70F8F3886F840D07`。

## 推断

同一清零值先后经手工 DMI/SBA（V109G）和 OpenOCD 原生 `mww`（V109I）均未改变读回。现有证据降低了“仅 V109G 的手工命令封装错误”这一解释的可能性，但仍不能证明写事务在芯片内部已提交：OpenOCD/SBCS 没有报错不是 APB/SYSCTRL 寄存器写提交的独立确认。

依据 RISC-V 数字设计说明，`PERI_RST[5]` 是 I²C soft reset，写 1 表示使能、写 0 表示关闭。当前该位稳定为 1，I²C 仍受复位；不得继续访问 I²C FIFO 或发 OLED 字节。

ARM 参考头文件把 I²C reset 映射在 bit2，而 RISC-V 设计说明映射在 bit5。该版本差异必须保留，不能为了试值而将 bit2 写入真实芯片。

## 下一步

停止本次 JTAG 写入尝试。请对目标板执行完全掉电再上电（拔掉 Type-C 及其它外部供电，等待电源指示熄灭后再接回），以 POR 恢复 `PERI_RST` 默认状态。重上电后先运行独立只读快照，确认 `PERI_RST=0`、`PERI_CLKEN` 与 I²C 寄存器状态，再重新初始化。若完整掉电后 bit5 仍为 1，暂停实物 I²C 调试并将手册/ARM 差异及两种写路径失败证据提交芯片设计方确认。

