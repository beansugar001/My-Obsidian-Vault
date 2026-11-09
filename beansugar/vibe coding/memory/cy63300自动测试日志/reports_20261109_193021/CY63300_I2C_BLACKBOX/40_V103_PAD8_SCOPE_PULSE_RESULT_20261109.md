# V103 Pad8 示波器脉冲测试结果（2026-11-09）

## 结论

本轮**没有产生 Pad8/SCL 脉冲**，因此示波器上保持 3.3 V 不能作为本次 GPIO 脉冲实验的结果。脚本在实际改动 Pad8/9 前发现 GPIOB 的 IDR 对应位为低，按停止条件退出。

测试前脚本曾将 `PERI_CLKEN` 从 `0` 写为 `1`，只打开 GPIO 外设时钟。随后独立收尾阶段尝试将其恢复为 `0`，但写后读回仍为 `1`。因此当前记录的 `PERI_CLKEN=0x1`，GPIO 时钟恢复**未确认成功**。SBCS 为 `0x20040404`，未报告 busy/error；这不能证明目标写已经生效。

## V103 脉冲阶段

- 阶段：`BBX_V103_PAD8_GPIO_SCOPE_PULSE_01`
- 结果：Pad 前置条件失败，GPIO Pad 配置未改，脉冲次数为 0，未发 I²C 事务。
- 关键采样：GPIOB IDR=`0x20`，Pad8/PB2 与 Pad9/PB3 输入位均为低；原 GPIOB ODR/DIR/OSOD/PUPD/AFR1 均为 0。
- 目标 MMIO：仅有一次 `0x4002180C <- 0x00000001`，用于开启 GPIO 外设时钟。
- OpenOCD 日志：`runs/BBX_V103_PAD8_GPIO_SCOPE_PULSE_01_20261109_181605_231931/openocd.combined.log`
- 日志 SHA256：`A774ECE64C3868E8CED60A3AD5D744341221BCBCA505E6969454BF0B6A882C6B`

## 收尾恢复阶段

- 阶段：`BBX_V103_GPIO_CLOCK_RESTORE_01`
- 条件检查通过：新会话确认 `PERI_CLKEN=1`，CPU halted，DMSTATUS=`0x00430382`，SBCS=`0x20040404`。
- 唯一目标写入：`0x4002180C <- 0x00000000`。
- 独立读回：仍为 `0x00000001`；恢复失败/未确认。未重试。
- 最终 SBCS：`0x20040404`。
- OpenOCD 退出码：0；阶段状态：`FAIL_OR_UNKNOWN`（Tcl 完成标记出现，但读回校验失败）。
- 日志：`runs/BBX_V103_GPIO_CLOCK_RESTORE_01_20261109_181843_339073/openocd.combined.log`
- 日志 SHA256：`EE1C7DC2627603574B67A86807DBF94363D3057CAF06A9D5CA209571B829BE95`

## 解释与下一步

用户确认探头接线正确：示波器测的是预期的 Pad8/SCL 点，地夹接目标板 GND。因而本轮观察到的“外部节点约 3.3 V”与“GPIOB IDR 的 PB2/PB3 位为低”是芯片侧的真实待解释矛盾。由于本轮没有切换引脚功能，也没有发生输出动作，不能据此判断 OLED 或 I²C 控制器故障。下一步应先离线核对《数字设计说明》中的 PADMUX/Pad 到 GPIO 端口位映射，以及 GPIO 输入缓冲/复用选择定义；之后再设计只读采样，确认读的寄存器和位确实对应 Pad8/9。当前不重复 GPIO 写入或脉冲实验。

本轮没有进行恢复重试、复位、resume、Flash/NVR 操作或 I²C FIFO/I2C_EN 写入。两个阶段的 marker 与原始日志均保留。
