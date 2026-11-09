# V92G/H 实测：打开 I²C 时钟并读取控制器基线

日期：2026-11-09（Asia/Shanghai）  
范围：恢复 `PERI_CLKEN[5]`，随后只读核对 I²C 控制器状态。  
目标：推进 OLED I²C 测试，不宣称 OLED 通信已恢复。

## 结果摘要

| 阶段 | 目标写入 | 关键读回 | 结论 |
|---|---|---|---|
| V92G | `0x4002180C <- 0x00000020`，一次 | CLKEN=`0x20`、RST=`0`、SBCS=`0x20040404` | `PASS_CLOCK_ON_SAME_SESSION` |
| V92H | 无目标 MMIO 写入 | MODULE=`0x02`、FIFO=`0x05`、DIV0=`0x20`、DIV1=`0x30`、MODE=`1`、ADDR=`0x133`、I2CM_CTRL=`0`、HOLD=`5`、STA/RAW=`0` | `PASS_READ_ONLY_BASELINE` |

## V92G：唯一差异写入

旧版 V4.4/V7.8 成功前置流程会在 I²C 时钟关闭时读取一次 `MODULE_CTRL (0x40002800)`。此前 V92F 跳过此读取，时钟写回读0。本阶段只增加这一次旧流程读取，其他前置安全条件继续检查，然后执行一次 `PERI_CLKEN=0x20`。

`MODULE_CTRL` 读取返回 `0x00000000`，明确标为 clock-off diagnostic raw value；时钟关闭时该值不作为 I²C 控制器有效状态。

写前：IDCODE=`0x1E200A6F`；指定 DAPLink serial 匹配；CPU 从 running 一次 halt 到 halted；DMSTATUS=`0x00430382`；SBCS=`0x20040404`；PERI_RST 三读为0；PERI_CLKEN 三读为0。

写后同一 OpenOCD 会话：PERI_CLKEN=`0x00000020`、PERI_RST=`0x00000000`、SBCS=`0x20040404`。目标 MMIO 写入计数为1。没有 reset、resume、Flash/NVR、复位位、FIFO 或 I2C_EN 写入。

原始证据：

- 运行目录：`runs/BBX_V92G_MODULE_CLOCKOFF_READ_GATE_01_20261109_145249_706766`
- `combined.log` SHA256：`2FAB5BAEA5833181CB90002D91D04D49EA78EC86B19E78E151AFFF77F01B473A`
- 固定输入：OpenOCD `EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27`；配置 `CB6064F0866A495C067C634FAB91C9A2084AE1805E171C6BCA5758F3A241A4A1`；Tcl `9D3796E84B377845D1B11522218D1C5CA9287AA2356F922A9946AF0812F8A79D`。

## V92H：独立只读快照

新 OpenOCD 会话确认探针和 TAP、一次 halt 后 DMSTATUS=`0x00430382`，再只读检查外设。时钟门控维持 `0x20`、复位为0；I2C_EN(bit0)=0；FIFO 状态 `0x05` 表示 FIFO 空；STA、RAW 中断状态为0。CLK_DIV0/1 保持文档默认值 `0x20/0x30`。

目标 MMIO 写入计数为0。SBCS 每个事务前后均无 busy/error，最终 `0x20040404`。

原始证据：

- 运行目录：`runs/BBX_V92H_I2C_ENABLED_CLOCK_BASELINE_READ_01_20261109_145446_934676`
- `combined.log` SHA256：`97F68E5C2ADF6F66AAA62175F89F642303D587773B46A141922D6DC55EE39796`
- 固定 Tcl SHA256：`A0A2290802DB1674FFDBC40A3F4F6AF0E0F75D1913F6B8727ED3010AC19D689A`

## 根因判断边界

V92G 单次成功表明时钟门控写路径可以生效；相对 V92F，最明显的脚本差异是 gate-off 时读了 `MODULE_CTRL`。它可能本身或其带来的 SBA/桥接时序使能了成功路径，也可能只是运行间歇性、设备状态变化的巧合。单次对照不足以宣称已证明因果或发现手册规定的必要步骤。后续不应把 clock-off `MODULE_CTRL` 值用于配置判定。

这次只解决了 I²C 时钟门控和基线确认。尚未设置 Pad8/9、写 I²C 配置、发送 START/地址/数据，也没有观测 OLED ACK 或显示 `Hello`。

## 下一步

保持 I²C 控制器关闭、FIFO 空的条件，单独将 `PERI_CLKEN` 从 `0x20` 增至 `0x21` 以打开 GPIO 时钟，并独立读回。成功后再按 ARM GPIO 初始化配置 Pad8/SCL 与 Pad9/SDA，读回其 AF、开漏、pull-up 和空闲高状态；然后按 ARM 初始化顺序做 I²C 控制器设置与最小 ACK 测试。每阶段独立 marker，失败即停。
