# V109A2 GPIO 时钟与输入状态结果

## 结论

本阶段通过：GPIO 外设时钟已开启，GPIOB 快照读取成功。对 GPIOB 寄存器偏移的核对与数字设计说明及 ARM 头文件一致。快照中 PB2、PB3 的输入位为低；这表示芯片输入采样为低，不能单凭寄存器读数换算成引脚电压，也不能证明 OLED 或接线损坏。下一步先开启 I²C 外设时钟并读取控制器复位/寄存器状态，之后按确认过的 PAD8/PAD9 复用配置流程操作。

## 实物操作记录

- 阶段：`BBX_V109A2_GPIO_CLOCK_ENABLE_02`
- 时间：2026-11-09 20:50:30 +08:00
- 调试器：CMSIS-DAP/DAPLink，序列号 `07000001006700343500000a4e57354aa5a5a5a597969908`
- TAP/IDCODE：唯一 `riscv.cpu`，`0x1E200A6F`
- CPU：启动时 running；发送一次 `halt 2000` 后 halted
- DMSTATUS：`0x00430382`
- PERI_CLKEN 写前：`0x00000000`，三次一致
- PERI_RST 写前：`0x00000000`，三次一致
- 唯一一次目标 MMIO 写：`0x4002180C <- 0x00000001`（仅 GPIO 时钟 bit0）
- PERI_CLKEN 写后：`0x00000001`，三次一致
- PERI_RST 写后：`0x00000000`，三次一致
- 结果：`PASS_GPIO_CLOCK_ON_SNAPSHOT`
- 目标 MMIO 写入次数：1；未写 I²C 时钟、复位、PADMUX 或 I²C 控制器寄存器；未执行 FIFO/I2C_EN。

## GPIOB 快照

| 寄存器 | 地址 | 读值 | 含义 |
|---|---:|---:|---|
| ODR | `0x40000100` | `0x00000000` | 软件输出锁存为 0 |
| DIR | `0x40000104` | `0x00000000` | PB0..PB5 输入方向 |
| IDR | `0x40000150` | `0x00000020` | PB5=1；PB2/PB3 输入采样为 0 |
| OSOD | `0x40000158` | `0x00000000` | 未配置开漏/开源 |
| PUPD | `0x4000015C` | `0x00000000` | 未配置内部上拉/下拉 |
| AF_DG | `0x40000168` | `0x00000000` | 数字复用选择为 GPIO 功能 0 |
| AF_ANA | `0x4000016C` | `0x00000000` | 模拟复用选择为 0 |

本板目标线应连接到 Pad8/Pad9；设计说明映射为 GPIOB[2]/GPIOB[3]。因此当前采样低与 GPIO 模式下该两输入为低相符，但要确认真实电平仍需示波器在 Pad8/Pad9 对 GND 测量。历史示波器记录不可替代本次同时点测。

## 寄存器地址依据交叉核对

- 数字设计说明 `D:\project\RISCV-63300\_analysis\design_doc_full.txt`：GPIOB 基址 `0x40000100` 的地址由 ARM 设备头文件基址定义确认；GPIO 寄存器表列出 ODR `0x00`、DIR `0x04`、IDR `0x50`、OSOD `0x58`、PUPD `0x5C`、AFR1/数字 AFR `0x68`、模拟 AFR `0x6C`。
- ARM `D:\project\63300\CY63300_测试样例\Device\cj32l01xx.h`：`M0_GPIO_TypeDef` 字段偏移与上述一致；`GPIOB_BASE = PERIPH_BASE + 0x0100`，`PERIPH_BASE=0x40000000`。
- 设计说明 Pad 复用表：Pad8=`GPIOB[2]`，I2C SCL 位于复用功能索引 3；Pad9=`GPIOB[3]`，I2C SDA 位于复用功能索引 3。因此数字 AFR 字段 PB2 `[8:6]`、PB3 `[11:9]` 设为 3 时，两字段合并掩码为 `0x000006C0`。尚未将该值写入芯片。

## 原始证据与完整性

运行目录：`C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX\runs\BBX_V109A2_GPIO_CLOCK_ENABLE_02_20261109_205030_764908`

- `openocd.combined.log` SHA256：`08A626F88E71E6851A4CE486A4B3110CF0D80333D5DCD4B2487BD1D2F55610D4`
- `openocd.stderr.log` SHA256：`E6128116F8F2F6E14046EC277AC9E6A4DDCF4C172490661330F3ABF27C59870D`
- `openocd.stdout.log` 为空（SHA256 为标准空文件哈希）；完整 OpenOCD/Tcl 输出由 combined 与 stderr 保存。
- Tcl SHA256：`EC8CEF8DDFC09F2DFCCA5A5CF9EEDD5668DA67471504CEE354D315B0F88D03C4`
- runner SHA256：`5BB8CA04553D5BFDB12554663565BE56DEB245B0344615F5CC2FBF52E536B052`
- 配置 SHA256：`CB6064F0866A495C067C634FAB91C9A2084AE1805E171C6BCA5758F3A241A4A1`
- OpenOCD SHA256：`EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27`

本报告与原始日志目录一并归档至 Obsidian 测试日志库。下一实物阶段仍按单阶段、单个有界写入并独立读回执行；任何状态不符立即停止。
