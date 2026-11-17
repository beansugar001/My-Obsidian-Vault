# V142 STM32F103 OLED 地址应答对照

## 工程和硬件

- STM32 工程 D:/project/stm32/4-1oled，Hardware/OLED.c 第 5–22 行为 PB8/SCL、PB9/SDA 开漏，76 和 90 行使用写地址字节 0x78，对应 7 位 0x3C。第 64–65 行发第九拍，原示例没有读取 ACK。User/main.c 第 7–9 行初始化后显示 HelloWorld!。
- ST-Link V2J37S7，SWD DPIDR 0x1BA01477，CPUID 0x411FC231，DBGMCU_IDCODE 0x20036410，Flash 容量字段 64 KiB。ST-Link 读到目标供电约 3.20 V。
- 对照沿用 STM32 与 OLED 的现有接线。CY63300 本轮未访问。原工程未改动。

## 实测

首次入口连接成功，初始化后直接检查 CPU 状态时未通过，停止在 Halt 和 SRAM 写之前。修复为先 poll，再确认原程序运行，独立第二阶段成功。

832 字节探测程序只加载到 STM32 SRAM 0x20003000，读回校验后从 0x2000325C 执行。ST-Link 随后在 0x2000333C 暂停 CPU 并读取带唯一完成标记的 SRAM 邮箱。GPIOB PB8/PB9 开漏，地址后释放 SDA，在 SCL 高时采三次。空闲与 STOP 后均确认两线读高。

| OLED 7 位地址 | 线上写地址 | 第九拍三次 PB8/PB9 输入 | 结果 |
|---|---|---|---|
| 0x3C | 0x78 | 0x100、0x100、0x100，SCL 高、SDA 低 | ACK |
| 0x3D | 0x7A | 0x300、0x300、0x300，SCL 高、SDA 高 | NACK |

RCC_CFGR=0x001D040A，与项目 HSE 8 MHz、PLL ×9 的配置吻合。程序每半周期等待 720 个 CPU 周期，按项目时钟约 10 µs，再加 GPIO 操作开销。两个地址探测帧各约 0.231 ms。测量来源为 CPU 周期和 GPIO 输入，未采示波器波形。

原有 Flash 起始 3932 字节与 Project.axf 转出的镜像逐字节一致。测试前后读取全部 64 KiB 逐字节一致，SHA256 均为 1902C216B72468BD155FE2D5E5CF9C2B37CE104245A95A2EF2084911CC141CEB。结束时仅 STM32 复位并重启原 HelloWorld! 固件，OpenOCD 确认目标为 running。屏上显示的现场观察由用户完成。

## 对 CY63300 的意义

0x3C 有了正常速率下的正对照。V141 在 CY63300 上的秒级 GPIO 探测未观察到 ACK，两组结果仍有主机、时序和引脚路径差异。下一轮 CY63300 只用确认过的 0x3C；优先在 OLED 插座侧观察首次 START、八位地址与第九拍。示波器探头难接时，可将 STM32 的 PB8/PB9 配为输入并用 SRAM 程序记录 CY63300 波形，需要共地并确认由单一电源给 OLED 供电。本轮未执行这项接线或测试。

## 日志

第二次原始合并日志 SHA256 FB93364179C19EA3F5D64B98364B9BD502B8290394B275DC808DF078423E841B。两次原始日志、邮箱、测试代码、Flash 对照和阶段标记一并保存。
