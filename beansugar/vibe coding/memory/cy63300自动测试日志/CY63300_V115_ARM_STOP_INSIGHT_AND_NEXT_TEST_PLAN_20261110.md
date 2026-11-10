# CY63300：ARM 卡点经验与下一步 I²C 测试计划

日期：2026-11-10
状态：仅完成资料分析和测试规划；本轮未连接或操作芯片。

## 当前问题摘要

RISC-V 端的控制器配置读回大体成立，但单字节事务没有得到进展证据。V113A3/A5 最近完整状态是 PERI_CLKEN=0x21、PERI_RST=0、MODULE_CTRL=0x0F、ADDR=0x3C、FIFO_STA=0x104（TX_NUM=1）、STATUS=0x1（WORK=1、DATA=0）、RAW_INTR=0。软件 GPIO 探测曾对 OLED 地址得到 NACK，但连接器端实际波形没有被确认。

V114 没能建立 CPU-store 对照：Program Buffer 读回为 0，未执行 postexec；DPC 写回后 hart 转为 running。V114C 因 hart running 停止在 I²C 读取前。因此，V113 是最后完整 I²C 快照，当前芯片 I²C 状态未知，不能把该旧快照当作当前状态。

## 新 ARM 记录的发现

用户提供的 ARM 项目记忆记载了另一类卡点：TX FIFO 已被消耗（TX_NUM=0），I2CM_WORK=1、I2CM_DATA=1，而软件仍先等待 DATA 清零，之后才发送 STOP。由于 Master 使用 STOP_MODE=SCL_L，退出 DATA 阶段可能依赖软件先发送 STOP，形成状态机死锁。

记录中的修正是：先确认 DATA 曾置位，随后等 TX_NUM=0，立即调用 I2C_GenerateStop()，再等待 WORK=0。记录称之后 Master 发送返回成功，Slave 连续收到 0xA5/0x5A。

这项经验与本项目相关，但目前不是同一个已证实状态：RISC-V 最近快照仍是 TX_NUM=1、DATA=0，卡在 FIFO 字节尚未消费/事务未推进阶段。ARM STOP 修正不能单独解释这一点。ARM 记录是项目记忆而非原始全量日志，作为有价值的流程证据使用，不等于证明 ARM 与 RISC-V ASIC 实现完全一致。

## 下一步测试计划

### 阶段 0：干净启动后的只读基线

先让目标经历一次完整断电/重新上电或用户确认的重新插拔，避免继续沿用 V113 的活动 FIFO 状态。之后使用新阶段和新日志，只读确认 IDCODE、hart 状态、DMSTATUS、SBCS、PERI_CLKEN 和 PERI_RST。仅当时钟确认开启、复位释放且 SBA 空闲无错时，才读 I²C 内部寄存器；若时钟关闭，不把 I²C 内部读数当有效状态。若 hart 未 halted、SBA busy/error、或基线不稳定，停止，不写寄存器。

### 阶段 1：单字节事务的可观测性准备

采用现有确认过的 OLED 目标地址 0x3C 和单字节 0x00，不混入 0x78 作为普通 payload。示波器 CH1 观察 Pad8/SCL、CH2 观察 Pad9/SDA；两只探头地夹接同一板上 GND。使用 SDA 下降沿触发，单次捕获覆盖地址阶段和后续时钟。若无法安全接探头，本阶段不以寄存器 IDR 高低代替波形证据。

### 阶段 2：一次事务并记录状态先后

在新授权阶段中只执行一笔单字节事务，沿用 ARM 轮询流程的关键顺序：地址预置、控制器使能、写一个 payload。记录事务前后及轮询中的 sticky 事件：seen_WORK、seen_DATA、seen_TX_NUM_zero、NACK/错误、STOP 是否已发、WORK 是否退出，并保存最终 FIFO/STATUS/RAW 与示波器图。V114 已显示 DMI Program Buffer 读回为 0，不能依赖 OpenOCD postexec 来跑轮询；V93 的 RAM canary 也未证明能从 RAM 入口执行。应先离线准备最小 RISC-V 诊断固件并审计其写入白名单；若唯一可用的启动办法涉及 Flash 编程，必须先单独授权并备份，不能把本轮规划视作烧录授权。

只有观测到 seen_DATA=1 且 TX_NUM=0，才在该单次事务中按 ARM 修正发 STOP，然后等待 WORK 清零。若 TX_NUM 始终为 1、DATA 始终未出现，停止事务并记录，不发 STOP、不重写；这将支持“事务未启动/未推进”分支，而非 STOP 死锁。不得自动重试。

## 结果分支

| 结果 | 判断 | 后续方向 |
|---|---|---|
| FIFO 始终有 1 项，示波器没有 START/SCL | 仍停在事务启动或控制器取 FIFO 之前 | 对照真实 ARM 源码、Master 地址寄存器语义、启动条件和 RISC-V 外设映射；不测试 STOP 修正 |
| 有 START/地址时钟但 NACK | 总线已启动，问题转向地址、从机应答或电气波形 | 保存波形与地址位序，核对 OLED 7-bit 地址 0x3C、上拉及接线 |
| DATA 曾置位、TX_NUM 降 0，随后 WORK 卡住 | 与 ARM 记录的 STOP 等待死锁同型 | 在已观测条件下验证立即 STOP 是否使 WORK 清零 |
| STOP 后 WORK 清零、OLED 接收可确认 | 主机事务时序推进 | 再分阶段测试 OLED 初始化命令，最后发送 Hello 显示数据 |
| 状态不一致、SBA 错误或 hart 状态异常 | 证据无效/目标状态异常 | 立即停止，保留现场；不恢复、不重试、不复位 |

## 约束

- 本轮没有执行新实物测试或任何目标写入。
- 下一项实物事务需新阶段记录与明确授权；不能沿用此前阶段授权。
- 不再重复 V113A3 的配置顺序作为“新测试”，而是在保持已知配置不变时增加瞬态状态记录和真实线路波形。
- ARM 记录中的 0x50、分频 1000/1000 和双芯片角色不适用于 OLED 目标，不能直接照搬。

## 依据文件

- 用户提供的 CY63300_项目记忆_问题与进展记录.docx（ARM 双芯片联调记录，2026-11-09）。
- reports_current/V113_CONFIG_ORDER_VS_FIFO_STALL_20261110.md。
- reports_current/V114_PROGBUF_AND_DPC_RESULT_20261110.md。
- ARM 轮询样例 D:\project\63300\CY63300_测试样例\IIC_Master.c，关键发送流程约 301–578 行。

