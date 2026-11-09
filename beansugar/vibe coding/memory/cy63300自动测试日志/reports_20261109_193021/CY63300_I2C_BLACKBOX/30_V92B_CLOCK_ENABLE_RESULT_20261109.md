# V92B 单次 PERI_CLKEN 写入结果

日期：2026-11-09（Asia/Shanghai）
阶段：`BBX_V92B_I2C_CLOCK_ENABLE_ONCE_01`

## 实物结果

- 探针：DAPLink `07000001006700343500000a4e57354aa5a5a5a597969908`；JTAG TAP=`riscv.cpu`；IDCODE=`0x1E200A6F`。
- CPU 初始为 running；本阶段仅发出一次 `halt 2000`，确认 halted。当前 CPU 保持 halted。
- DMSTATUS=`0x00430382`；SBCS preflight=`0x20040404`，写事务轮询值也保持 `0x20040404`，未见 busy/error。
- 写前 `PERI_RST=0` 三次、`PERI_CLKEN=0` 三次，均一致。
- 目标 MMIO 写：**恰好 1 次**，`0x4002180C <- 0x00000020`。
- 写后独立 SBA 读事务读到 `PERI_CLKEN=0x00000000`；同时 `PERI_RST=0`。结果 `FAIL_OR_UNKNOWN`，目标时钟未获读回确认。
- 根据停止条件，未再写、未读 I²C 内部寄存器、未复位、未 resume、未恢复、未断电或重试。I²C FIFO/WORK/RAW 的当前状态未知。

## 证据解释

DMI/SBA 命令层没有报告 busy/error，但目标寄存器没有变化。这只能证明调试器侧命令完成且读回仍为 0；**不能区分**“写未真正提交到 SYSCTRL/AHB”与“写到达但 SYSCTRL 未接受/未更新”。SBCS 无错误不是目标寄存器写入成功证明。本结果尚不能归因到 I²C APB 控制器，因为失败点在开启 I²C 时钟的 SYSCTRL 寄存器。

唯一写入已消耗本阶段 marker。不得对同阶段自动重跑，也不得据此继续尝试其它写值。

## 原始证据

运行目录：`runs/BBX_V92B_I2C_CLOCK_ENABLE_ONCE_01_20261109_142414_372766/`

- `command.json`：执行 argv、工作目录、互斥进程/端口快照及文件 SHA256。
- `openocd.combined.log` SHA256：`A35A79899490CE8713090397C14848A81DE333050A39C113E7F1F6BDF93E0C98`
- `openocd.stderr.log` SHA256：`C9991CBB2996A9DAB362BCB79BF90F7634AEE0AFF4363519B8A82D33AB576440`
- `result.json`：OpenOCD 退出码 0、Tcl 完成标记存在，但阶段结果 `FAIL_OR_UNKNOWN`，目标写计数 1。
- 阶段 marker 已创建并保留。

## 下一步建议

停止实物写入。先离线对照 V4.4 成功和本轮失败的 SBA DMI 顺序、`SBCS` 变化及实际 `SBDATA0` 时序；同时审查 V76/V77 已有 SRAM/CPU-store 对照结果，判断是否已有足以区分通用 SBA 提交问题与 SYSCTRL 专用路径问题的证据。若没有，下一项硬件实验应单独设计一个最小、可验证的通用写路径对照，并明确地址和值；本报告不授权该实验，也不建议重复本次时钟写入。
