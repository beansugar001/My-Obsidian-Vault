# V112A2 GPIO 内部上拉判别结果

## 实测

V112A2 新阶段预检通过：IDCODE=`0x1E200A6F`，CPU halted，DMSTATUS 正常，SBCS=`0x20040404`，GPIO 时钟位为 1、I²C 时钟位为 0，PERI_RST=`0`。GPIOB ODR/DIR/OSOD/AFR1 均为 0，PUPD 原值为 0。

执行唯一一次目标写：`GPIOB_PUPD (0x4000015C) <- 0x00000300`。读回 PUPD=`0x300`；GPIOB IDR 从 `0x20` 变为 `0x2C`，PB2/Pad8(SCL) 和 PB3/Pad9(SDA) 两位都从低变高。最终 SBCS=`0x20040404`。没有发送 START/地址帧，没有写 I²C 控制器/FIFO/I2C_EN，没有复位、resume、烧录或重试。

## 结论边界

这证明：在 GPIO 默认配置下，两条线的输入采样读低；打开 B2/B3 对应的内部上拉后，输入采样转为高。最符合当前证据的解释是这两根线上缺少有效外部上拉，或相关 Pad 在无内部上拉时处于浮空。它不能证明外部 OLED 插座电压，也不能单独判定载板连线或 OLED 状态。

当前 GPIO 内部上拉保持开启；GPIO 时钟保持开启；I²C 控制器时钟仍关闭。下一步可在独立阶段、先确认 `PUPD=0x300` 且总线空闲高后，只发一次 `0x3C` 写地址帧并采样 ACK。该测试仍不发送 OLED 配置命令或显示数据。

## 证据

- 原始日志目录：`runs_local_v109/BBX_V112A2_GPIO_PULLUP_SIGNATURE_01_20261110_103308_338854`
- Tcl / 执行器 SHA256：见该目录 `command.json`
- 综合日志 SHA256：`25BD83B2862536258BF46C0F5FEAC0D936564396C6F3336684E6252921D66C4E`
- 目标 MMIO 写入次数：1
- 阶段 marker：`markers/BBX_V112A2_GPIO_PULLUP_SIGNATURE_01.attempted.json`，保留，不可重跑。
