# V8.8D–F：按 V4.4 SBA 顺序恢复时钟并配置 ARM I²C 引脚

日期：2026-11-05（Asia/Shanghai）

## 结论

本轮按当天 V7.8 已验证的 V4.4 连续 SBA `SBADDRESS0 → SBDATA0` 顺序重试。此前 V8.8B/C 的单次时钟写读回不可见；本轮 V8.8D 的 `PERI_CLKEN=0x20` 独立读回两次均成功。随后 V8.8E 将 GPIO 时钟位加入为 `PERI_CLKEN=0x21`，读回通过。V8.8F 按 ARM 样例配置 Pad8/PB2=SCL、Pad9/PB3=SDA 为释放态开漏、上拉、AF3，配置后输入读回两线高。

这证明本轮时钟门控和 GPIO 引脚配置的 SBA 写入可见；**尚未证明 I²C START、OLED ACK 或任何 OLED 显示内容**。

## 分阶段实测

| 阶段 | 实际动作 | 结果 |
|---|---|---|
| V8.8D `BBX_V88D_V78_EXACT_CLOCK_REPRO_01` | 预检后一次写 `0x4002180C <- 0x20`；100 ms 后独立读 CLKEN 两次，并读 PERI_RST、MODULE_CTRL | PASS；CLKEN=`0x20` 两次；RST=`0`；MODULE_CTRL=`0x2`；1 次目标 MMIO 写 |
| V8.8E `BBX_V88E_GPIO_CLOCK_AFTER_I2C_CLOCK_01` | 前置要求 CLKEN=`0x20`；一次写 `0x4002180C <- 0x21`；独立读回 | PASS；保留 I²C bit5 并打开 GPIO bit0；1 次目标 MMIO 写 |
| V8.8F `BBX_V88F_GPIOB_PAD8_PAD9_I2C_01` | 先核对 CLKEN/RST、模块、FIFO、STA 和 GPIO 默认值；配置 ODR release、开漏、上拉、输出方向、AF3 | PASS；5 次目标 GPIO 写，每项读回；AFR1=`0x6C0`，IDR=`0x2C`，B2/B3 两位均为高；MODULE=`0x2`、FIFO=`0x5`、STA=`0` |

共同调试身份：DAPLink `07000001006700343500000a4e57354aa5a5a5a597969908`；IDCODE=`0x1E200A6F`；DMSTATUS=`0x00430382`；最终 SBCS=`0x20040404`。OpenOCD 每阶段仅在 CPU 初始运行时 halt 一次；没有 reset、resume、Flash/NVR、I²C 软复位、FIFO 数据写入或 START。

## 对“之前不是能写吗”的回答

是的，历史 V7.8/V7.8B/C 曾证明该芯片在对应阶段能写 SYSCTRL 时钟门控和 CLK_DIV0。本轮 V8.8D 用同一类 V4.4 地址后紧接数据的 SBA 顺序再次把 CLKEN 从 0 写到 `0x20`，读回成功。之前 V8.8B/C 的失败因此不能说明芯片永久失去写能力；也不能仅凭本轮成功就断定唯一原因，V8.8D 相比 V8.8B/C 的具体脚本顺序和访问序列有多处差异。

## 原始记录与 SHA256

- V8.8D 日志：`runs/BBX_V88D_V78_EXACT_CLOCK_REPRO_01_20261105_203949_272049/openocd.combined.log`  
  SHA256：`21590921B32B6B61FED7725576B0241D9A099D9AAF03C00145A93E8658F1EE0A`  
  写入计数：1；状态：`PASS_V44_ORDER_CLOCK_VISIBLE`。
- V8.8E 日志：`runs/BBX_V88E_GPIO_CLOCK_AFTER_I2C_CLOCK_01_20261105_204347_491938/openocd.combined.log`  
  SHA256：`F4C6FC10F514EF5036B388CD27A601871FB2F33D684B910ACB629D4E2CC6471D`  
  写入计数：1；状态：`PASS_V44_ORDER_CLOCK_VISIBLE`。
- V8.8F 日志：`runs/BBX_V88F_GPIOB_PAD8_PAD9_I2C_01_20261105_204438_561045/openocd.combined.log`  
  SHA256：`BCFBB564622CD312597CB55245170D6C09473D1D4C94DDB53D6B1A3052C3A9F2`  
  写入计数：5；状态：`PASS_PAD8_PAD9_RELEASED_AF3_IDLE`。

每个阶段的 `command.json`、`result.json`、分离的 stdout/stderr 和唯一 marker 均保存在对应目录；marker 保留，不复用。

## 当前状态与下一步

当前已确认：`PERI_CLKEN=0x21`、`PERI_RST=0`、Pad8/PB2 与 Pad9/PB3 已配置并读高、I²C 控制器仍为禁用/空 FIFO/空闲状态。需在下一新阶段先按正确 RISC-V 手册地址只读采集 DIV0、DIV1、MCTR、HOLD、MODE、ADDR、MODULE_CTRL、FIFO、STA、RAW；然后按 ARM `IIC_Master.c` 顺序设置必要分频（样例 H/L=1000，经驱动的 `-1` 变成 `0x3E7/0x3E7`）、HOLD/MCTR/FIFO/MODE，设置 OLED 7-bit 地址 `0x3C`，最后启用 I2C_EN。每项写后独立读回并在首次异常处停止。控制器配置通过后，才单独评估一笔 OLED 命令事务；此前同类事务会卡在 FIFO/WORK，必须采用有限轮询并保存状态，不能批量塞 FIFO 或自动恢复。

