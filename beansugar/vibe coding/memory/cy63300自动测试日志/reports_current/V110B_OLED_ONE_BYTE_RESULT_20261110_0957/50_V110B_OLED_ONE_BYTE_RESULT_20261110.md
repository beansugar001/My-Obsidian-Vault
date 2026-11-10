# V110B OLED 单字节测试结果

日期：2026-11-10。OLED 已由用户接好；V110B 各阶段独立记录，未写 Flash/NVR。

| 阶段 | 实际结果 | 目标 MMIO 写次数 |
|---|---|---:|
| B0 只读 | JTAG/DM/SBA 正常；PERI_CLKEN=0、PERI_RST=0，三次稳定 | 0 |
| B1 时钟 | 写 PERI_CLKEN=0x21，读回确认；I²C 控制器初始关闭 | 1 |
| B2 引脚 | Pad8/9 配为 GPIOB2/3 开漏 AF3，释放后 IDR 两位均高 | 4 |
| B3 FIFO 配置 | MCTR=2、ADDR=0x3C、TX/RX FIFO 使能，控制器仍关闭；读回正常 | 3 |
| B4 控制器使能 | MODULE_CTRL 可写位读回为使能，FIFO 空、WORK=0 | 1 |
| B5 单字节 | 写 TX FIFO 一个 `0x00`；200 次轮询未观察到完成 | 1 |

B5 首次与最后一次轮询均为：`STATUS=0x1`（WORK）、`FIFO_STA=0x104`（TX 仍有 1 字节）、`RAW_INTR=0`（未观察到 STOP/NACK）、`GPIOB_IDR=0x2C`（SCL/SDA 输入采样高）。脚本以 `I2C_TRANSACTION_COMPLETION_NOT_OBSERVED` 停止；未发送第二字节、未复位或恢复。200 次轮询由 JTAG 多次读取组成，不能将其等同于 200 ms；本次会话持续约 76 秒。

这与 V109F 的 FIFO 卡住状态一致，说明本次上电恢复后单字节传输仍未完成。GPIO 输入采样高不能证明线上没有瞬时波形；也不能证明 OLED ACK 或确认 OLED 已接收到数据。当前保留控制器工作和 FIFO 排队现场，不能进入 OLED 初始化或显示 Hello。

各阶段命令、原始日志、阶段 marker、脚本和 SHA256 在归档包中。B5 合并日志 SHA256：`8445A24A4145101F4BD3C43D12305BA2B42B7726D6214742B2FCCDF394A5BDD3`。

下一步应分析 ARM 例程的 CPU 写 FIFO 与本次 JTAG/SBA 写 FIFO 的差异、实际主机时钟及启动条件，并结合公司工程师答复设计可区分实验。当前不再次写 FIFO 或脉冲软复位。
