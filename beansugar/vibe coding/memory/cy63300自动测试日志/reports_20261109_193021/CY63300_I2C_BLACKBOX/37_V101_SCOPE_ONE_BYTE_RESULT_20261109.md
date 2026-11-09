# V101：调试器恢复后重建 I²C 并进行单字节示波器探测

日期：2026-11-09（Asia/Shanghai）

## 结果

V100A 首次阶段因当时 OpenOCD 找不到 CMSIS-DAP 而在任何目标写入之前失败，阶段 marker 保留。用户随后确认调试器已恢复；使用新阶段 V101，OpenOCD 成功识别探针并完成测试。

V101A 单次开启 I²C 时钟，读回 CLKEN=`0x20`、RST=0；V101B 开 GPIO 时钟，读回 CLKEN=`0x21`、RST=0。V101C 将 Pad8/SCL、Pad9/SDA 配为 AF3/开漏/上拉/释放，IDR=`0x2C`。V101D 按 ARM 顺序设置 DIV0/1=`0x3E7`、FIFO、地址 `0x3C`，最后使能控制器；读回 MODULE=`0x0F`、FIFO=`0x05`、STA/RAW=0、IDR=`0x2C`。

V101E 写入单个 TX FIFO 字节 `0x00`，在 40 次有限轮询无进展后按 ARM 超时路径发一次 STOP。随后状态仍为 FIFO=`0x104`、TX_NUM=1、STA=`0x01`、RAW=0、DATA_seen=0；STOP 后也未 idle。最终 SBCS=`0x20040404`、DMSTATUS=`0x00430382`。本阶段结论为 `FAIL_OR_UNKNOWN`，帧未完成。脚本的阶段执行完成只代表采样及停止流程走完，不代表 I²C 成功。

## 写入预算与日志

| 阶段 | 目标写入 | 日志 SHA256 |
|---|---|---|
| V101A | `PERI_CLKEN <- 0x20` 一次 | `2F93B4F90ACA5C22E9D0378E2320E648782A6CD49386E74ABC3FCA09140340DA` |
| V101B | `PERI_CLKEN <- 0x21` 一次 | `93674BD4BE3FA2587BF8FD29AD570D24D640ED13CB25E5777C5372B31FE2420A` |
| V101C | 5 次 Pad GPIO 配置写入 | `C872918356BCBD496A60A31B7719DA7D071A24C8B356187B29BDAC26F4BE413F` |
| V101D | 5 次 ARM 控制器配置写入 | `EE5D83AE7CC58C61F434D866139490E430B54B93C8391A3E84902B66D3768A2C` |
| V101E | TX FIFO `0x00` 一次；MCTR STOP `0x02` 一次 | `541CFD639EC5A1A4569A97ADD03CB407DE041C7BF8AB6BBD1B13DCFB03517685` |

原始 OpenOCD 日志分别保存在 `runs/BBX_V101*_20261109_*/openocd.combined.log`；各阶段 marker 均保留。

## 当前状态与下一步

V101E 后控制器再次挂起。没有自动复位、resume、重试或额外写入。**本机没有示波器采集接口，所以仍需用户报告屏幕捕获结果。** 请提供 CH1/SCL 是否有脉冲、CH2/SDA 是否出现 START、地址后的第 9 个时钟 SDA 是否拉低（ACK），以及 Single 是否冻结。当前不要追加 FIFO 或 STOP 写入；先保存波形画面，再掉电重插并只读确认 FIFO/WORK 已清空。

## 为什么 STOP 没能让它空闲

设计说明对 `I2CM_CTRL.STOP`（bit 1）的条件写得很明确：`STOP=1` 时，只有 **TX FIFO 已空**，I2C master 才终止传输并生成 STOP；`FIFO_STA[11:8]` 的 `TX_NUM` 则表示仍在 FIFO 内的数据字数。因此本次 STOP 发出时 `TX_NUM=1`，控制器之后也一直没把该字节取走，STOP 请求并不具备清空非空 FIFO 的规范保证。这解释了“STOP 后仍 WORK=1”，但没有解释为什么 TX FIFO 首字节始终不出队。

手册没有在本地摘录中给出可直接清空 TX FIFO 的独立 flush 位。ARM `I2C_Cmd(DISABLE)` 只是清 `MODULE_CTRL.I2C_EN`，源码没有承诺它会清 FIFO；不能把它当作已验证的恢复方法。以前 `PERI_RST[5]` 从 1 写回 0 未能读回释放，软件复位也不是可靠清理方案。当前实测可确认的恢复方法仍是完整断电后重上电；随后必须先只读确认 FIFO=`0x05`、WORK=0。

**下次避免再次卡住的关键不是换一个 STOP 值：** 先完整断电清空当前状态；下一轮只重新配置到控制器空闲，不写 TX FIFO。示波器用正常/自动触发观察 SCL/SDA 静态电平；之后再做一笔事务时预先用 Single 触发。如果波形确实没有 START/SCL，停止写 FIFO，转查 START 产生条件、Pad8/9 复用及芯片端输出；若有脉冲，再看地址 ACK。Single 未冻结本身只有在确认触发源、边沿、阈值和探头位置正确后，才支持“没有被设定的触发边沿”，仍不能替代波形记录。
