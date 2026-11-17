# V151 GPIOC 输出和 OLED ACK

- 复用 V144 的 STM32 高阻采样，CY 仅在 GPIOC0/C1 开漏拉低，一次 SCL、两次 SDA；I²C 时钟关闭。
- 预检 GPIOC DIR、AFR1、AFR2、ODR、OSOD、PUPD 均为 0、两线为空闲高。只写 OSOD=3 和 DIR=1/2/0，正常 7 次目标写；失败最多追加一次只释放。
- 只有 STM32 实际采到正确六个边沿，才使用 GPIOC0/C1 做 OLED 0x3C 单地址 ACK。ACK 时 C0/C1 均输入。保留两项独立证据。
