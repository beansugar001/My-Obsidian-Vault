# CY63300 V159C 独立上电显示 Hello 实测

**通过。2026-11-11，CY63300 重新上电后，OLED 清楚显示 Hello。**

## 条件与结果

- 主 Flash 第 0 扇区已写入并独立校验 V159 入口镜像。实测时 OLED 由 CY63300 H2-1/VDD_IO 供电，H2-3 为 SCL，H2-4 为 SDA，双板共地。DAPLink USB 保持拔除，用户只重新接入 CY63300 的 Type-C。
- STM32 PB8/PB9 为高阻输入，CRH=0x44444444，只采集 SCL/SDA。
- STM32 记录 2727 个边沿，无溢出。启动前段记录了 7 组没有完整字节的跳变。随后连续 6 帧的地址、控制字、命令和字模载荷与 V159 数据逐字节一致。六帧分别为 26、5、42、5、42、3 字节，共 123 字节，每个字节均收到 ACK，每帧均有 STOP，末尾两线回到高电平。
- 用户报告：“接好了，然后重新对cy63300上电，显示hello”。
- 本轮保持 CY63300 的 DAPLink 断开，未读其上电后 SRAM 邮箱。成功依据为独立抓包、用户观察和此前已核对的 Flash 镜像。此前热状态邮箱的失败退出属于单独一次启动前检查。

## 复核材料

- capture/capture_mailbox.bin 是 STM32 原始采集结果，boot_capture_edges.csv 是边沿表，boot_capture_decode.json 是逐帧逐字节解码。
- observer 包含采集器和离线解码脚本。
- 烧录证据见相邻的 2026-11-11_V159B_PROGRAM_AND_BOOT。

