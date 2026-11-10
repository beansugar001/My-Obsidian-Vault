# CY63300 V119C/V119D：DPC 后现场与 I²C 只读状态

日期：2026-11-10（Asia/Shanghai）

## 结论

- V119B 的 SRAM canary **没有得到 CPU 执行证据**。DPC 抽象写请求顺序是 DATA0 后 COMMAND；命令结束时 ABSTRACTCS 无错误，但 DPC 独立读回 `0x00000064`，不是 SRAM 地址 `0x20008000`，且 hart 回到 running。因此这不是“先请求后写入顺序遗漏”的证据。
- V119C 新会话只读发现 hart 为 running。按门控停止，没有读取 I²C 状态，目标 MMIO 写入为 0。
- V119D 新阶段发送一次 `halt 2000`，确认 halted 后只读。I²C 控制器处于 `WORK=1`，`FIFO_STA=0x00000A04`。按《CY63300 数字设计文档》§4.19.4：`TX_NUM[11:8]=0xA`、`TX_EMPTY=0`、`RX_EMPTY=1`，即寄存器报告 TX FIFO 中有 10 个 word、TX FIFO 非空、RX FIFO 为空。这明确是控制器仍忙且队列未排空；读数没有波形/ACK信息，不能判定从机收到了任何数据。
- DPC 写入可能启动了 Flash 中已存的 V118 程序，也可能触发了参考 Debug RTL 所示的调试复位/运行行为；实物的 DPC=`0x64`、hart running 与之相符，但**无法仅凭现有日志证明 V118 确实执行到写 FIFO，也无法证明 TX_NUM=10 是它写入的**。这是待查的因果链。

## 实测记录

| 阶段 | 硬件动作 | 结果 |
|---|---|---|
| V119C | 连接并只读查询状态；发现 running 后立即停止 | `CPU_NOT_HALTED_READONLY_STOP`；未读 I²C；MMIO写 0，halt/resume/reset请求 0 |
| V119D | 一次 halt 请求，随后只读寄存器 | halt 成功；DMSTATUS=`0x00430382`；SBCS=`0x20040404`；CLKEN=`0x21`；PERI_RST=`0` |

V119D I²C 快照：`MODULE_CTRL=0x0F`、`FIFO_STA=0x0A04`、`CLK_DIV0=0x3E7`、`CLK_DIV1=0x3E7`、`MODE=1`、`ADDR=0x3C`、`MCTR=2`、`HOLD=5`、`STA=1`、`RAW_INTR=0`。

`MODULE_CTRL=0x0F` 与之前 ARM 顺序配置的读回值一致；`CLK_DIV0/1=0x3E7`、MODE/ADDR/MCTR/HOLD 也匹配 V118 参数。可确认这些寄存器当前读回保持了配置值。`STA=1` 对应 WORK 位为 1，控制器尚未空闲。`RAW_INTR=0` 仅说明该寄存器当前读回为零，不等同于已收到 ACK。

## FIFO_STA 位域解码依据

《CY63300 数字设计文档》提取文本 `_analysis/design_doc_full.txt` §4.19.4：

- bits `[19:16]`：`RX_NUM`
- bits `[11:8]`：`TX_NUM`
- bit 2：`RX_EMPTY`，1 表示 RX FIFO 为空
- bit 0：`TX_EMPTY`，1 表示 TX FIFO 为空

因此 `0x00000A04` → `RX_NUM=0`、`TX_NUM=10`、`RX_EMPTY=1`、`TX_EMPTY=0`。手册对 bit 3 的文字有“RX_FULL”名称与 TX FIFO 描述混杂的笔误，本解码未依赖 bit 3。

## 写请求顺序问题

本轮没有发目标寄存器写入。V119B 的抽象 DPC 写已经按 `DATA0 -> COMMAND` 提交，随后等抽象命令完成并独立读 DPC；命令状态未报 abstract error，但目标值未保持。因此当前证据不支持把问题简单归因于漏了“请求再写”的顺序。

更准确的区分是：

1. OpenOCD/DMI 抽象命令被接受并完成；
2. 这不证明芯片把候选值写入 DPC；
3. DPC 实物值回到 `0x64` 且 hart running，暗示该实现可能把 DPC 写路径解释为启动/复位控制，或者存在 DPC 写入语义差异；
4. 参考 `jtag_dm.v` 确实有 DPC 写触发 `dm_reset_req`、解除 halt 的分支，但这只是参考 RTL，不能代表流片版实现。

所以要先厘清**PC/DPC 能否被当前硬件路径显式设置、复位入口和 Flash 启动行为**，再设计 SRAM 执行方式。继续试不同写入顺序或重复写 DPC会增加复位/执行副作用，当前不应做。

## 证据边界与风险说明

- V119B canary 的 `load_image` 与 `verify_image` 通过，只证明 OpenOCD 对 SRAM 地址的写读通道可用；不证明 CPU 执行。
- V119B 曾临时覆盖 scratch code 与 mailbox，结束前均恢复并 verify；DPC 写后 hart 转为 running，因此不能排除 Flash 程序在此期间运行并造成 CPU 侧副作用。OpenOCD 日志记录的目标 MMIO 写次数为 0；这并不等价于“CPU没有发出 MMIO”。
- V119D 的寄存器值是在 hart halted 状态下读取。会话结束后没有再次查询，故不声称断开调试器后 CPU 当前仍 halted。
- 没有执行新的目标 MMIO 写、软件复位、resume、Flash/NVR、断电或 FIFO 操作。

## 下一步

1. 保持硬件不再启动或改写。先离线核对 V118 入口/链接地址、复位向量 `0x64` 周边反汇编、启动 ROM/boot 流程和芯片手册中 DPC/DMCONTROL 语义，解释 `TX_NUM=10` 是否可能由 V118 固件或错误入口执行产生。
2. 找到一个不依赖抽象 DPC 写的、手册支持的“halt 后设定执行入口”方法；若没有证据，不再尝试 `resume <address>` 或 DPC 写。
3. 后续先在独立新阶段只读采集并确认 CPU halted 后的寄存器状态；在任何 START/FIFO/STOP 操作前，必须有可观测、可恢复的 CPU 程序执行和邮箱方案。
4. 只有查明启动路径并评估现有 Flash 镜像及其潜在副作用后，才进入新的授权阶段。不要自动清 FIFO、复位、恢复或重试。

## 原始记录

- V119C 运行目录：`runs_local_v119/BBX_V119C_POST_DPC_READONLY_20261110_01_20261110_154551_195738`
- V119C 合并日志 SHA256：`F8A57D874CE083343F83A9E549D3BB96B2A6BA5955147A3A22D3B3FC4831D125`
- V119D 运行目录：`runs_local_v119/BBX_V119D_HALT_ONCE_READONLY_20261110_01_20261110_154722_688143`
- V119D 合并日志 SHA256：`1C2474422922FD1B77F8274349AA865F836B12BE0672E794B10066380C2A9289`
- V119D stderr SHA256：`FD784367C741BB3E31FF4747486EBD8945F0761A1F722BFC060AF3AC24046925`
