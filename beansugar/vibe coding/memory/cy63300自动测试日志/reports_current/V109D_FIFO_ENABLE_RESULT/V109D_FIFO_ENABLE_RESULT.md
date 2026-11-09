# V109D FIFO 使能阶段结果（脚本判定错误）

本阶段真实执行了三次目标 MMIO 写：`MCTR 0x40002828 <- 0x2`、`ADDR 0x40002824 <- 0x3C`、`MODULE_CTRL 0x40002800 <- 0xC`。前两者读回与期望相同。第三次芯片读回 `0xE`，脚本错误地要求精确等于 `0xC` 后停止。数字设计说明定义 bit1 为复位值1的只读保留位，因此读值 `0xE` 与 TX/RX FIFO enable 位 [3:2] 已置位且 I2C_EN bit0 仍为0一致。脚本退出码0并不等于阶段PASS；阶段报告为 `FAIL_OR_UNKNOWN (checker expectation mismatch)`，无 FIFO payload、无I2C_EN、无START。

随后独立阶段 V109D2 三次读取 MODULE_CTRL 均为 `0xE`，并确认 FIFO_STA=5（空）、STATUS=0、RAW_INTR_STA=0、SCL/SDA 输入采样都高，PERI_CLKEN=0x21、PERI_RST=0。由这组独立读回可确认当前状态为：TX/RX FIFO 已使能、I2C_EN 未使能、控制器空闲。没有重复原 FIFO enable 写入。

V109D 原始运行目录：`C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX\runs_local_v109\BBX_V109D_I2C_FIFO_CONFIG_NO_ENABLE_01_20261109_211329_625512`

- combined log SHA256：`6CDE065206BB8CBC93338B679FA83556CA1E36CDA39F7F8FFE172894715CF24E`
- stderr SHA256：`3C38BD74FDAEAAF7EE9F6962466A9D55BB1251915FB8C35C166CD9C9CF17C16A`
- marker 和实际脚本一并归档；不删除、不重跑本阶段。
