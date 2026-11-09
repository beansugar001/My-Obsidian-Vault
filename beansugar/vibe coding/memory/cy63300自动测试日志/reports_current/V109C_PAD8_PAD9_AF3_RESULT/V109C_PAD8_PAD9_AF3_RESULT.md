# V109C Pad8/Pad9 开漏释放与 I²C AF3 结果

## 实物结果

- 阶段：`BBX_V109C_PAD8_PAD9_AF3_RELEASE_01`
- 时间：2026-11-09 21:10:24 +08:00
- TAP/IDCODE：唯一 `riscv.cpu` / `0x1E200A6F`
- DAPLink：`07000001006700343500000a4e57354aa5a5a5a597969908`
- CPU：初始 running；一次 `halt 2000` 后 halted；DMSTATUS=`0x00430382`
- 前置条件：PERI_CLKEN=`0x21`，PERI_RST=`0`；MODULE_CTRL=`0x2`，FIFO_STA=`0x5`，I²C STATUS=`0`
- 控制器保持禁用，FIFO 未启用，未写 I2C_EN，未向 FIFO 写数据。

## PAD 配置顺序和读回

依照 ARM GPIO 驱动“ODR/电气类型/方向设置后，再选数字 AF”的顺序，并使用 RISC-V Pad 复用表的 Pad8/9 映射，按顺序执行 4 次目标 MMIO 写；每次均等待 SBA 空闲并独立读回：

| 次序 | 地址和值 | 结果 |
|---|---|---|
| 1 | GPIOB ODR `0x40000100 <- 0x0000000C` | 回读 `0x0000000C`；先预置高电平锁存，后续开漏输出保持释放 |
| 2 | GPIOB OSOD `0x40000158 <- 0x0000000C` | 回读 `0x0000000C`；PB2/PB3 开漏 |
| 3 | GPIOB DIR `0x40000104 <- 0x0000000C` | 回读 `0x0000000C`；方向输出，但开漏且锁存为 1，线路释放 |
| 4 | GPIOB AF_DG `0x40000168 <- 0x000006C0` | 回读 `0x000006C0`；PB2/PB3 的 AF 字段均设为 3，即 Pad8/Pad9 的 I²C 功能 |

配置后 GPIOB IDR=`0x0000002C`，PB2/Pad8=SCL 输入采样为 1、PB3/Pad9=SDA 输入采样为 1；MODULE_CTRL 仍为 `0x2`。状态：`PASS_PAD8_PAD9_AF3_RELEASED`。这次 IDR 高与此前 GPIO 模式的 `0x20`（PB2/PB3 采样低）不同，说明在当前开漏释放 + AF3 设置后，芯片采样到两条线都高；这为进入控制器初始化提供了直接证据，但还未证明波形、START/ACK 或 OLED 响应。

## 依据

数字设计说明 Pad 复用表（`design_doc_full.txt` 第 145 页）映射 Pad8=`GPIOB[2]`、Pad9=`GPIOB[3]`，两者 I²C 功能索引为 3；AF_DG 字段每 GPIO 引脚占 3 bit，PB2 字段 `[8:6]` 与 PB3 字段 `[11:9]` 设成 3 后为 `0x6C0`。ARM `cj32l01xx_gpio.c` 的 GPIO_Init 先更新 PUPD/OSOD/DRIVE/SPEED/DIR；ARM FS 示例随后做 AlternateFunction。ARM 示例用 GPIOA0/1 和 AF2，不能套用到本 RISC-V Pad8/9 映射。

## 停止边界与日志

本阶段不做 I²C 配置写、FIFO 写或总线事务。异常则无自动恢复/重试；本次完整通过。

运行目录：`C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX\runs_local_v109\BBX_V109C_PAD8_PAD9_AF3_RELEASE_01_20261109_211024_991754`

- combined log SHA256：`A455F07E81B3B2B7BF3FAEEBB859F4BA8113DDA4B80246AC6B70F26017B5F6E0`
- stderr SHA256：`06577640CB7A718DF2DC5E4D319DAAFAD7BF0E8126331CF7D062553A09D3A22B`
- 完整命令、脚本和工具 SHA256 记录在 `command.json`；marker 与全部原始输出一并归档。
