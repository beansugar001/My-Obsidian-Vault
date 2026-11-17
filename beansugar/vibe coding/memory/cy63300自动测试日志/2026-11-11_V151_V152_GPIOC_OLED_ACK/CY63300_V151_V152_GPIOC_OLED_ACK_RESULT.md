# CY63300 V151/V152 GPIOC 输出与 OLED 地址应答

## 已验证

接线沿用 V150。CY63300 H2 两线在当前实物上对应 GPIOC0/SCL、GPIOC1/SDA。STM32 PB8/PB9 高阻采样，OLED 继续接在 STM32 侧。CY63300 只开 GPIO 时钟，I²C 控制器时钟关闭。

| 阶段 | 实测 |
|---|---|
| V151 开漏输出 | GPIOC OSOD=3，ODR=0。CY 用 DIR 拉低 SCL 一次、SDA 两次。STM32 捕获六个边沿，输入顺序 0x200、0x300、0x100、0x300、0x100、0x300，两线回到空闲。CY 目标写 7 次 |
| V152 地址帧 | CY 用 GPIOC0/C1 发 0x78，即 7 位 0x3C 写。第九拍 DIR=0，两线释放为输入，3 次 GPIOC_IDR 均为 0x1（SCL 高、SDA 低）。CY 目标写 26 次 |
| STM32 独立验证 | 记录 26 个边沿，无溢出、无模糊采样，解出 START、0x78、ACK、STOP。首尾 PB8/PB9 都高 |
| 结束状态 | CY GPIOC_DIR=0，STM32 PB8/PB9 高阻，OLED 端空闲 |

V151/V152 均通过。验证了同一线束下从 CY63300 GPIO 输出到 OLED 的地址帧和从机 ACK。此前基于 GPIOB2/B3 的输入、输出与位模拟试验并未使用当前 H2 两根线的实际 GPIO 映射。

## 下一项

下一项发送一条能观察到变化的显示命令。例如在 OLED 已开启的情况下，发 0x78、0x00、0xA7，使显示反色，检查每字节 ACK 和屏幕变化，然后再验证文字或像素数据。V152 只发送地址，未发送显示命令。硬件 I²C 主机仍需单独确认引脚映射与 SCL 输出能力。

## 证据

V151 GPIO 合并日志 SHA256 AD0F79082D871E0349702020425D642BA474BAE4BD111C4372EF3C69B7EDA2FF。
V152 GPIO 合并日志 SHA256 8D4470C31ECA1DFD7D36BAF3986E498B88EC8997294CEF85E9FE6682C551EE30。
保留两次 STM32 邮箱、V152 边沿 CSV/解码、CY 原始日志、离线检查及独立 marker。
