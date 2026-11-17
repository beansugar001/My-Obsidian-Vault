# CY63300 V139 冷启动高驱动实验结果

## 实测结果

| 项目 | 结果 |
|---|---|
| JTAG | 100 kHz，指定 DAPLink，IDCODE 0x1E200A6F |
| CPU | 初始 running，Halt 一次后 halted，DMSTATUS=0x00430382 |
| 冷启动 | PERI_CLKEN 与 PERI_RST 各三读均 0 |
| GPIO 输入 | PB2/PB3 加内部上拉前 IDR 三读 0x20，之后三读 0x2C |
| 发送前配置 | DRIVE=0xC、AFR1=0x6C0、PERI_CLKEN=0x21、MODULE_CTRL=0xF、ADDR=0x3C；FIFO_STA=5、I2C_STA=0、RAW=0 |
| TX 写入 | 一次写 0x00 到 0x40002808；SBCS=0x20040404，无 busy/error |
| TX 结果 | 60 组样本全为 FIFO_STA=0x104、I2C_STA=1、RAW=0，TX_NUM=1、WORK=1、DATA=0 |
| 采样跨度 | 首组距 TX 写入约 0.39 秒，末组约 22.78 秒 |
| 操作计数 | Halt 1 次，目标写入 17 次，其中初始化 16 次、FIFO 1 次、STOP 0 次 |

结果为 **TX_STALLED_FIFO_1_WORK_1**。配置读回全部符合预期。发送前已经设置并核对高驱动，控制器仍未消耗 FIFO 字节。PAD1 保持默认复用。实物未采集外部波形，芯片引脚上的 START、地址与 OLED ACK 尚未证实。0x00 为 OLED 控制字，未发送完整命令。

## 脚本和日志

离线验证覆盖 10 个分支，包括配置不符、GPIO 拉不高、FIFO 写入无迹象、NACK、SBA 错误、卡住和出队后 STOP。OpenOCD noinit 验证了脚本路径及时间戳命令。首次启动在 Windows CIM 进程查询权限处退出，无阶段 marker、无目标访问。之后用具备查询权限的入口执行，互斥快照无冲突。原始日志和一次性 marker 已保留。

实测 OpenOCD 退出码 0，脚本按硬件语义返回 1。原始合并日志 SHA256 为 B4FFE49DB544E0EAB5B987F1B42101237E8190832A4E9623D0FEB06FDDB33ACF。

## 下一项判别

若要验证 PAD1 复用是否在 START 前影响 SDA 输入，下一次冷启动保持 V139 的 OLED、PB2/PB3、分频与流程，只新增发送前 PAD1=AF6，保留 PAD0/TDI。若仍卡在同样状态，应把重点移到从机地址与应答的独立验证，以及芯片的实际 SCL/SDA 输入路由。上一次 GPIO 输入模拟曾采到 NACK，可作为线索，采样结果仍受主机位模拟速度及板级条件影响。
