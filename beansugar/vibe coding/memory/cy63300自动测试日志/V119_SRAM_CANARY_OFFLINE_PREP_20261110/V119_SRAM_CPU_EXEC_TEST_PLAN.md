# 下一次测试计划：让 CPU 从 SRAM 执行最小程序

日期：2026-11-10
范围：规划与离线证据核对；本文件生成过程中没有连接芯片、写 SRAM、resume、复位或操作 Flash/NVR。

## 结论先说

现在还没有可信证据证明 CPU 成功执行过 SRAM 程序。V117C 的结果 JSON 写着 `SRAM_PROGRAM_EXECUTED`，但原始 OpenOCD 日志报告 PC 写入不匹配，随后读到的邮箱是旧 V116 的 `MBOX/0x600D`。因此该 PASS 是历史脚本的假阳性，需要在后续报告中标成“未证实”，不能继续当成功基线。

下一次不要改从 `0x64` 跑。V118 镜像在 `0x62` 有一条 32 位指令，`0x64` 是这条指令的后半段；而且 V118 的 `_start` 在 0，负责设栈并调用 `main`。PC 错误读回到 `0x64` 不是有效的启动地址，也不是应该迁就的目标值。RISC-V 的压缩指令扩展允许 16 位对齐，但半字对齐不代表它一定是指令边界。[RISC-V ISA 对齐规则](https://docs.riscv.org/reference/isa/v20240411/unpriv/intro.html)

## 已有证据

| 阶段 | 已做事项 | 结果与限制 |
|---|---|---|
| V93 | SRAM 装载并 verify，尝试从 `0x20008000` resume | PC 写回不一致，邮箱未变；执行未证实 |
| V95 | 可逆 DPC 写读 | 候选 DPC 值未读回；恢复原值成功 |
| V114 | Program Buffer / DPC 路径检查 | PROGBUF 写入后读回仍为 0；postexec 未执行；DPC 写后观察到 hart running。参考 RTL 只能解释现象，不能代替流片证据 |
| V117C | 装载 1208 字节 SRAM 程序并 verify，尝试 resume | 原始日志报 `Written PC (0x20008000) does not match read back value (0x0)`；邮箱为旧 V116 标记。不是执行通过 |
| V118C | V118 Flash 镜像独立读回通过，尝试 `resume 0` | 报 `Written PC (0x0) does not match read back value (0x64)`；不能证明从 Flash 正常启动 |

V117C 的 SRAM 链接布局把程序放在 `0x20008000`，邮箱放在 `0x2000F000`，栈顶为 `0x20020000`。V118 程序的 SRAM `.data/.bss` 均为 0 字节，仍需在测试前做当前 CPU halted 状态和工作区的只读检查，不能把旧 map 当作当前 SRAM 内容证明。

## 推荐路线

### 阶段 0：离线修正与准备

1. 检查本机 OpenOCD 0.10.0 中 `resume <address>`、PC/DPC 读写和“写入后读回核对”的真实命令路径；把旧 Tcl 的 `capture resume` 行为单独审计清楚。
2. 编译一个极小 SRAM canary：入口固定为 `0x20008000`，仅用 RV32I 基础指令（关闭 RVC/压缩指令和 relaxation），启动时设栈，向邮箱写“开始标记”、本轮唯一 stage ID、完成标记，再进入自循环。
3. 固件禁止访问 MMIO、I²C、Flash/NVR，也不依赖 UART。输出 ELF、BIN、MAP、反汇编及 SHA256；静态核对入口、代码长度、栈和邮箱不重叠。
4. 改写执行器判定：任何 `Written PC ... does not match` 都不得报告 PASS；邮箱必须同时符合本轮唯一 magic、stage ID 和完成状态。历史 `MBOX/0x600D` 一律判旧数据。

阶段 0 不连接目标。若无法从已安装 OpenOCD 源码/可复现离线行为解释 PC 设置路径，或新镜像/内存布局审计不通过，就停在此处并向芯片/工具供应方确认 Debug Module 的 DPC/PC 语义，不试 `0x64`、其他猜测入口或替代写入途径。

### 阶段 1：一次受控 SRAM canary（需另行明确授权）

前置只读门槛：

- 唯一 TAP、预期 IDCODE `0x1E200A6F`、指定 DAPLink、DMSTATUS halted、SBCS idle/error-free。
- CPU 状态如为 running，最多一次 `halt 2000` 并确认 halted；失败就停。
- 记录 DPC、DCSR、misa 与 DMSTATUS；对关键读数重复采样。DPC/DCSR 或 misa 异常/不稳定时不执行。
- 读取 canary 区和邮箱旧内容，保存快照；只在确认这块 SRAM 是本轮 scratch、且不与当前栈/数据冲突后继续。

单次执行路径：

1. 将唯一 canary 装载到 `0x20008000`，以独立读回确认字节级一致；失败不 resume。
2. 发出一次 `resume 0x20008000`，完整保存 OpenOCD 原始响应。不得因 PC 不匹配而尝试 `0x64`、重复 resume、改 DPC 或切换注入方式。
3. 若 resume 报错，记录为 `PC_CONTROL_FAIL_OR_UNKNOWN` 并停止自动执行。后续只在本阶段授权明确包含时，最多进行一次状态采样/必要 halt；单独读回邮箱和 DPC，避免把“OpenOCD 报错”误当成“CPU 一定没跑”或“CPU 一定跑了”。
4. 若 resume 命令无错，等待固定短窗口，然后最多一次 halt；读回本轮唯一邮箱标记及 DPC。邮箱不匹配即失败/未知，不重试。
5. 如果测试前保存了 scratch 原值，只有 CPU 确认 halted 后才恢复该 SRAM 区并读回验证。恢复只针对 SRAM scratch；不触碰 MMIO 或非易失存储。

### 通过标准

同时满足以下全部条件才算 `SRAM_CANARY_PASS`：

- 镜像字节级 verify 通过；
- `resume` 没有 PC 写回不匹配；
- 本轮新写入的 magic、stage ID、完成标记三者全部精确匹配；
- 完成标记在执行前的快照中不存在；
- canary 区恢复（若启用）读回与原始快照一致；
- 日志中没有错误、超时或未解释的 hart 状态变化。

这只证明“CPU 可从指定 SRAM 入口取指并执行基础指令、写入 SRAM 邮箱”。它不证明 CPU store 到外设有效，也不证明 I²C FIFO 被消耗或 OLED 收到数据。

## 失败分支

| 观察结果 | 判定 | 下一步 |
|---|---|---|
| 装载或 verify 失败 | `SRAM_LOAD_FAIL` | 停止；检查 SRAM 地址/总线读写链，不 resume |
| PC 写回不匹配 | `PC_CONTROL_FAIL_OR_UNKNOWN` | 不换地址、不重试；独立只读检查 hart/DPC/邮箱；向供应方核对 DPC 实现和调试规范 |
| PC 错误但唯一完成标记出现 | `EXECUTED_BUT_DEBUG_READBACK_FAULT` | 证明本轮 CPU 确有执行，同时单独调查 OpenOCD PC 读回；不继续 I²C |
| PC 看似正常但唯一标记缺失 | `EXECUTION_UNPROVEN` | 停止；检查取指/异常/时钟/复位状态，不报 PASS |
| 唯一标记通过 | `SRAM_CANARY_PASS` | 另起新阶段，先计划最小 CPU-store SRAM 对照，再决定 I²C；不在本阶段顺带写 MMIO |

## 风险与操作边界

| 操作 | 风险 | 控制措施 |
|---|---|---|
| 只读 DMI/SBA 状态 | 低 | 新阶段保存日志；不在 busy 时操作 |
| halt | 中：改变 hart 状态 | 一阶段最多一次前置 halt；失败停止 |
| 向 SRAM 装载 canary | 中：覆盖 volatile SRAM 内容 | 只用核实 scratch；先保存原值；地址、长度固定 allowlist |
| resume canary | 中：CPU 执行代码 | 固件只写 SRAM 邮箱并自循环；无 MMIO/Flash/NVR；一次尝试 |
| DPC 直接写、Program Buffer postexec、Flash 重烧、复位/掉电 | 高/未证明可用 | 不纳入下一次实验 |

本规划不延续 V118 的 Flash 擦写或执行授权。任何真实 SRAM 装载、halt、resume 和 SRAM 恢复都应在下一轮明确列入独立阶段授权。

## 建议的下一动作

先完成阶段 0 离线产物和执行器修复；之后提交 canary 的 ELF/BIN/MAP/反汇编、哈希、固定地址范围、单次 Tcl 和停止条件供审阅。审阅通过后，再单独授权一次 SRAM canary 实物执行。当前不建议直接复用 V117C 镜像或脚本，因为其邮箱判定接受旧标记并漏判 PC 错误。
