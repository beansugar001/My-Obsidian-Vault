# CY63300 V140 冷启动 PAD1 对照结果

## 结果

PAD1 从冷启动起改为 GPIO 输入复用 AF6，首次发送前读回 GPIOA_AFR1=0x30、GPIOA_DIR=0。PAD0 字段为 0，JTAG 会话正常。与 V139 相比，唯一新增的目标写为 0x40000068 <- 0x30。其余沿用 PB2/PB3 开漏、高驱动、AF3，分频 0x3E7/0x3E7，OLED 7 位地址 0x3C。

| 项目 | 实测 |
|---|---|
| V140 01 | JTAG 正常，Halt 一次。PERI_CLKEN=0x21，与冷启动要求不符，目标写入 0 次 |
| V140 02 | 用户重新上电后，PERI_CLKEN/PERI_RST 各三读均为 0，Halt 一次 |
| 首发前 | I²C 时钟已开，MODULE_CTRL=0xF、FIFO_STA=5、I2C_STA=0、RAW=0 |
| 单次 FIFO 写 | 写 0x00，写后 SBCS=0x20040404 |
| 首发后 | 60 组样本全为 FIFO_STA=0x104、I2C_STA=1、RAW=0，约 22.7 秒 |
| 操作计数 | V140 02 为 17 次初始化写、1 次 FIFO 写、0 次 STOP |

V140 02 结果为 **TX_STALLED_FIFO_1_WORK_1**。FIFO 已入队，但采样中 TX_NUM=1、WORK=1、DATA=0。V139 与 V140 对照显示，把 PAD1 从默认复用切到 AF6 对此配置下的首字节卡住没有观察到改善。仍待验证的是芯片引脚是否发出了 START、地址是否上总线以及 OLED 是否应答。RAW=0 无法判定 ACK。0x00 仅为控制字，本轮无完整显示命令。

## 下一步

优先独立验证 OLED 地址应答。可在新冷启动下用 GPIO 开漏发送 0x3C 和 0x3D 的写地址，第九拍释放 SDA 为输入并记录读数。观察到 ACK 可建立相同芯片和接线下的外部通路正对照。全 NACK 时仍须区分 GPIO 模拟时序、输入路径和实际线路，必要时以同时捕获 SCL/SDA 的波形判断。V135 已在 0x3C 的第九拍正确释放并读到高，本轮未重复该探测。

## 日志

- 01 合并日志 SHA256 758548553DD6060FBC3E3B3694A89EF8D8F76E9EB6103CF1A214840183C9BF39
- 02 合并日志 SHA256 C2590E713DB2F924C65CCCFE34FCDC2869000DF8471CD812D7273C098BDB1376
- 两次 marker 独立保留。离线回归 12 项通过，包含 PAD0 状态不符及 PAD1 读回不符停止。
