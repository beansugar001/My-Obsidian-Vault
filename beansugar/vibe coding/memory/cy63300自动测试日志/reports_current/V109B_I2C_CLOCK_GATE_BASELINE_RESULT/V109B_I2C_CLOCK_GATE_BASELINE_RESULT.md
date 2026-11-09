# V109B I²C 时钟门控与控制器上电基线

## 实物结果

- 阶段：`BBX_V109B_I2C_CLOCK_GATE_BASELINE_01`
- 时间：2026-11-09 21:06:13 +08:00
- 唯一 TAP / IDCODE：`riscv.cpu` / `0x1E200A6F`
- DAPLink 序列号：`07000001006700343500000a4e57354aa5a5a5a597969908`
- CPU：初始状态未在摘要中展开；脚本至多发送一次 `halt 2000`，最终 halted
- DMSTATUS：`0x00430382`
- 写前 PERI_CLKEN：`0x00000001` 连读三次一致
- 写前 PERI_RST：`0x00000000` 连读三次一致
- 目标 MMIO 写入：恰好一次，`0x4002180C <- 0x00000021`（保留 GPIO 时钟 bit0，仅新增 I²C 时钟 bit5）
- 写后 PERI_CLKEN：`0x00000021` 连读三次一致
- 写后 PERI_RST：`0x00000000` 连读三次一致
- SBCS 最终：`0x20140404`，无 busy/error
- 结果：`PASS_I2C_CLOCK_ON_CONTROLLER_BASELINE`

## I²C 控制器读回

本阶段只读配置和状态寄存器，不读 FIFO 数据口，不写控制器寄存器：

| 名称 | 地址 | 实测 | 解释 |
|---|---:|---:|---|
| MODULE_CTRL | `0x40002800` | `0x00000002` | 仅保留位 bit1=1；I2C_EN/TX_FIFO_EN/RX_FIFO_EN 均为 0 |
| FIFO_STA | `0x4000280C` | `0x00000005` | TX/RX FIFO 均空（bit0、bit2=1） |
| CLK_DIV0 | `0x40002810` | `0x00000020` | 设计缺省值 |
| CLK_DIV1 | `0x40002814` | `0x00000030` | 设计缺省值 |
| MODE | `0x40002820` | `0x00000001` | 缺省 Master 模式 |
| ADDR | `0x40002824` | `0x00000133` | 设计缺省复位值，尚未设 OLED 地址 |
| MCTR | `0x40002828` | `0x00000000` | Master 控制字段为零 |
| HOLD | `0x40002838` | `0x00000005` | 设计缺省值 |
| STATUS | `0x4000283C` | `0x00000000` | Master/Slave 空闲，无传输活动 |
| RAW_INTR_STA | `0x40002858` | `0x00000000` | 无原始中断状态 |

这说明当前读通路可见设计文档描述的控制器复位/默认状态，I²C 时钟门已打开且控制器没有使能、FIFO 为空、总线状态位空闲。它不证明 SCL/SDA pad 已复用或外部 OLED ACK。

## 下一阶段依据与风险控制

ARM GPIO 驱动先设置开漏输出，再设置数字复用；但其示例使用 GPIOA0/1，不能照搬到当前 RISC-V 目标。数字设计说明的 RISC-V 复用表对应 Pad8=GPIOB2、Pad9=GPIOB3，I²C 功能索引 3，因此 AF_DG 字段目标为 PB2 `[8:6]=3`、PB3 `[11:9]=3`，值 `0x000006C0`。V109A2 读到 AFR1=0、DIR=0、OSOD=0、PUPD=0，IDR=`0x20`（PB2/PB3 采样低）；此前示波器报告过线路高电平，二者有已知矛盾。下一阶段必须先以开漏方式配置这两根线、保持控制器禁用，并观察寄存器/引脚反馈；不应以推挽方式驱高，也不应在完成空闲电平核验前启动 FIFO 或 I2C_EN。

## 日志与完整性

本地运行目录：`C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX\runs_local_v109\BBX_V109B_I2C_CLOCK_GATE_BASELINE_01_20261109_210613_884691`

- combined log SHA256：`F1611A0E05594A50F87468AD8337AFD890DAA277D36DA9BDD0C7F78FCD021FF3`
- stderr SHA256：`B8985C78A9ACDC74BF625ED87E6C54AB073B025BC68E1177B034CF0E34069EFF`
- runner/Tcl/OpenOCD/config 原始 SHA256 均记于 `command.json`，所有原始日志、JSON 和 stage marker 一并保存。
- 未执行 I²C FIFO、I2C_EN、复位、reset、resume、Flash/NVR 或断电。
