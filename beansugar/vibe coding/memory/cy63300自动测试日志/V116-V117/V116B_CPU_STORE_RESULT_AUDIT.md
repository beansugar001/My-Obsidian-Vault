# V116B CPU-store 实物结果与日志复核

## 结论

本轮 CPU 固件已从主 Flash 启动并写出邮箱完成标记。CPU 对 I²C TX FIFO 的两次直接 store 均反映在 FIFO 计数中：第一次后 `FIFO_STA=0x104`，第二次后 `FIFO_STA=0x204`。这说明 CPU store 能把两个字节送入 FIFO；但邮箱最终仍报告 `FIFO_STA=0x204`、`I2C_STA=0x1`、`RAW_INTR_STA=0`，因此没有证据证明控制器消费了字节、在 Pad8/9 生成了 START/时钟、或 OLED 收到 ACK。

邮箱中的若干诊断字段相互矛盾（例如 flags/轮询计数/最后 RAW 采样），不能用来判定 NACK、DATA 阶段或 STOP 是否真正发生。故本轮结果判为 **CPU FIFO 写路径通过；I²C 事务推进未知/未通过；OLED 未验证点亮**。

## 实际执行记录

| 项 | 实际结果 |
|---|---|
| 阶段 | `BBX_V116B_CPU_STORE_OLED_PROBE_20261110_01` |
| DAPLink | `07000001006700343500000a4e57354aa5a5a5a597969908` |
| IDCODE | `0x1E200A6F` |
| CPU | 初始 running；请求 halt 后 halted；固件运行后再次 halted |
| DMSTATUS | `0x00430382` |
| SBCS 初始 / 最终 | `0x20040404` / `0x00150000`（最终值不等于“写提交证明”；需按 SBCS 位域单独解释） |
| 固件 | 988 字节，写入主 Flash `0x00000000..0x000003DB`；Tcl 明确输出 `V116B_FLASH_VERIFY_PASS` |
| Flash 擦除 | 未执行；NVR 未触及 |
| 目标 MMIO 写操作 | 8 次，均为 Flash 时钟/时序/编程模式控制；固件另行执行 GPIO、SYSCTRL、I²C 配置与 FIFO store |
| 邮箱 | magic=`MBOX`、stage=`0x600D`，完成标记有效 |
| 初始化后关键值 | CLKEN=`0x21`，RST=`0`，MODULE=`0x0F`，ADDR=`0x3C`，初始 FIFO=`0x5`，STA=`0`，RAW=`0` |
| FIFO 写后快照 | 第一个字节后 `FIFO_STA=0x104`；第二个字节后 `FIFO_STA=0x204` |
| 最后快照 | FIFO=`0x204`（TX_NUM=2），STA=`0x1`（WORK=1、DATA=0），RAW=`0` |

## 原始证据与解析问题

运行目录：

`C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX\runs_local_v116\BBX_V116B_CPU_STORE_OLED_PROBE_20261110_01_20261110_133533_164756`

- `openocd.combined.log` SHA256：`A7FD8265A44982E0E656023123C7CC637AD6ADE19CF3B3158FA3A6EC6FC784C2`
- `openocd.stderr.log` SHA256：`32D13E88EED1CBABA8259599B4CE7012EC0DBEF2B56169F2FC45518DEB5580D8`
- `openocd.stdout.log` 为空；该 OpenOCD 构建把运行输出写到 stderr。
- Tcl 实际执行并记录 `verify_image` 后的完成标记 `V116B_FLASH_VERIFY_PASS`。Python 汇总器另要求日志含字面短语 `verified 988 bytes`，因此 `flash_programmed_and_verified=false` 是**解析器假阴性**，不代表 Flash verify 没运行。
- 运行器 `result.json` 的 SBCS 用十进制字符串 `1376256` 展示，换算为 `0x00150000`。本报告按原始 Tcl 行展示十六进制；不可将其当成 SBCS 无错误或事务提交证据。
- 26 字邮箱中少数字段（尤其 index 15、17、20）不符合固件源码预期。先前汇总器的 `mailbox_done=true` 仅验证头部 magic/stage；不会验证每个字段。因此只采信可独立交叉核对的初始化寄存器、FIFO 写后读数及末尾三项状态，不用异常字段推导瞬时事件。

## 与此前 SBA FIFO 试验的区分

此前通过 SBA/JTAG 往 TX FIFO 写入后也观察到 TX_NUM 增加或部分减少，但不能由此证明 I²C 引擎推进。本轮 CPU 直接 store 将“CPU 到 FIFO 的写入路径”与“控制器何时取走 FIFO 内容”分开：CPU store 的 FIFO 计数变化得到支持，但控制器仍处于 WORK=1、DATA=0、FIFO 非空。故“通用 SBA 写通路坏”不再是解释本次 FIFO 堵塞的充分假设；更可能的问题位于 I²C transaction engine / START 与输入反馈 / 时序配置交界，但仍没有波形证据，不能定为芯片损坏。

ARM 样例的关键差别：`I2C_Master_SendByte()` 每次只写一个 byte，然后轮询 `SR`、`RISR` 和 `FIFO_SR`；仅在观察到 `I2CM_DATA` 且 TX_NUM=0 后才发 STOP。V116B 为 OLED 发送控制字节 `0x00` 与命令 `0xAE` 连续写入，再自行做轮询/STOP，不能算严格复刻 ARM 的单字节事务函数。下次应先用一字节受控样例，复用 ARM 的“清状态→单字节入 FIFO→有限轮询 DATA/FIFO/错误→条件 STOP”顺序，同时修正/简化邮箱字段，避免依赖当前互相矛盾的 snapshot。

## 下一步与安全边界

V116B 后控制器末值为 WORK=1 且 FIFO 尚有 2 字节；不得在此状态再次追加 FIFO 数据或发 STOP。下一轮前先让目标板完整断电再上电，由用户确认完成；然后只读确认 JTAG 可用、`PERI_RST=0`、时钟开启后 FIFO 空、WORK=0、RAW 状态干净。若未回到空闲，停止。

固件已占用主 Flash 的 `0x00000000..0x000003DB`，原先“全片主 Flash 均为 0xFF”的备份仍保留，但当前芯片 Flash 已不再是空白。下一版固件不可直接覆盖本镜像：必须先评估新旧镜像逐位是否只发生 1→0；若需要 0→1，必须另行评估扇区擦除风险与恢复方式，不自动擦除。不得自动复跑已消费的 V116B marker。

### 下一次实验的判别目标

在 V116B 提供的 CPU store 已证实能增加 FIFO 计数后，下一次只发**一个** OLED 合法命令字节并按 ARM 每字节轮询路径执行，独立保存 `WORK/DATA/TX_NUM/RAW` 的首个变化与超时快照。如果 CPU 轮询也不能观察 FIFO 消耗，问题集中在 START/事务状态/反馈或寄存器语义，而不再是 JTAG/SBA 发出的 FIFO store 是否成功。如果 FIFO 消耗或出现 NACK/STOP 状态，则再据此决定下一小步；无波形时仍不能宣称物理线上有 START 或 ACK。
