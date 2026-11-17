# CY63300 V157 硬件 I²C 点亮 OLED 实测

**结果：PASS。CY63300 片上 I²C 主机经 H2 点亮 OLED，现场确认整屏亮起。**

## 接线与配置

- H2-3 为 SCL，H2-4 为 SDA，H2-2 共地，H2-1 留空。CY63300 使用 GPIOC0/C1 的 AF3，GPIOC_AFR1=0x1B。
- STM32 PB8/PB9 保持高阻输入，独立记录总线电平。OLED 仍接在这组共用信号线上。
- 沿用 V156 已验证配置。PERI_CLKEN=0x21，PERI_RST=0，DIV0/DIV1=0x3E7，HOLD=5，MODE=1，MODULE_CTRL=0xF，七位从机地址=0x3C。

## 执行与验收

1. STM32 先启动采集。CY63300 脚本核对配置，清除上次 MCTR 的 STOP 设置。
2. 逐个写入 TX FIFO：00 A6 8D 14 A5 AF。每次写入后确认 FIFO_STA=0x05、I2C_STA=0x03、RAW_INTR_STA=0。
3. 最后写 MCTR=0x02 请求 STOP。读回 FIFO_STA=0x05、I2C_STA=0、RAW_INTR_STA=0。
4. STM32 实测单帧：START → 78 ACK → 00 ACK → A6 ACK → 8D ACK → 14 ACK → A5 ACK → AF ACK → STOP。0x78 是 7 位地址 0x3C 的写地址字节。记录 166 个边沿，无溢出，帧前和帧后 SCL/SDA 均为高。
5. 用户观察结果：“整屏亮了”。

本轮 CY63300 共 8 次目标 MMIO 写入，包括 MCTR 清 STOP、6 次 TX FIFO 写入及最后一次 STOP 请求。结束时总线空闲，屏幕保持全亮。下一阶段通过同一硬件 I²C 路径初始化显示参数、写入 GDDRAM 并显示 Hello。

## 证据

- CY63300 实物日志与状态：cy_runs/20261111_150714_163595/
- STM32 原始邮箱、边沿 CSV 与解码 JSON：runs/read_20261111_150723_418513/
- 离线检查：offline_test.log
- SHA256SUMS.txt 记录报告、脚本、阶段 marker 和实测文件的 SHA256。

