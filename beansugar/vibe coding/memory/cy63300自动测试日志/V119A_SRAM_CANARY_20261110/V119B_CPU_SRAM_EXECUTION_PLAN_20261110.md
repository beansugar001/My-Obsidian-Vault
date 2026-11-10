# V119B 下一步计划：修复 SRAM canary 执行阻断

日期：2026-11-10（Asia/Shanghai）

## 当前问题拆分

| 项目 | 证据 | 判断 |
|---|---|---|
| V119A 脚本故障 | Tcl 报 `can't read "label_BEGIN": no such variable`；日志中无 `V119_CANARY_LOAD_BEGIN` 和 resume 请求 | 直接原因是 Tcl 把 `$label_BEGIN` 解析为单独变量；本轮 SRAM 没有被写 |
| DPC/PC 读数异常 | DPC 两次都是 `0x00000001`，MISA 两次都是 `0x70000000`；DCSR 两次 `0xC0` | 稳定读回不等于值正确。DPC 不符合 canary 的 RV32I 对齐；PC/DPC 访问语义尚未解释 |
| 历史执行失败 | V93、V117C 日志有 resume PC 写回读不一致；V95 DPC 写读未成功；V114 记录过 DPC 操作后 hart 状态变化 | 重复直接 resume 或写 DPC 风险高；需先审查对应 OpenOCD 实现和既有原始日志 |
| OpenOCD 源码 | 本机 `D:\project\tools\tinyriscv-master` 中未找到与当前 0.10.0 构建匹配的 `src/target/riscv/riscv.c` / `riscv-013.c` | 不能从当前二进制日志推断其完整 PC 写入细节；先取得匹配源码/构建提交或供应方说明 |

## 已完成的离线修正与回归

- `v119_read_mem` 使用 `format` 拼接 mailbox 标签，避免 `$label_BEGIN` 插值错误。
- `v119_sram_loaded` 在调用 `load_image` 前设为 1，加载中途失败时可进入受限恢复逻辑。
- 新增 DPC 非 4-byte 对齐时的前置停止门；当前 `0x1` 会在 SRAM dump/load 和 resume 前停止。
- 离线验证：Tcl `info complete`、Python runner 编译、mailbox BEGIN/END 标签实际生成、DPC 对齐表达式（奇数阻断/对齐值通过该门）均 PASS。
- 这些是脚本控制流检查，不是实物 SRAM 执行证据。

## 下一步顺序

### A. 先完成静态根因审查，不碰硬件

1. 找到与本机 `Open On-Chip Debugger 0.10.0+dev-00914-g4cb81306a-dirty` 匹配的源码或构建提交。
2. 追踪 `resume 0x20008000` 是否会写 DPC、如何读回、在哪些状态下清/置 halt/resume 请求，以及写回不匹配后 CPU 状态如何处理。
3. 对比 V93、V117C、V119A 的配置、target 命令、DPC 读法和原始错误；不写 DPC，不执行 progbuf。
4. 向芯片/工具供应方确认该流片 Debug Module 的 DPC CSR abstract access 与 resume 行为；区分参考 RTL、OpenOCD 代码和实物日志。

### B. 重新准入的只读条件

只有在 A 解释了 PC/DPC 操作，并且新只读会话满足以下条件时，才考虑 SRAM canary：

- DAPLink 序列号与唯一 TAP/IDCODE正确；CPU 可确认 halted；DMSTATUS/SBCS 正常。
- DPC/MISA 通过供应方定义或可交叉验证的读数检查；任何读回仍是 `DPC=1` 或无法解释的 MISA 值，立即停止。
- 新建全局唯一 V119B marker 和运行目录；绝不复用 V119A marker。
- SRAM scratch `0x20008000..0x2000804B` 保存 76 字节原值，再 load/verify 76-byte canary。
- 最多一次 `resume 0x20008000`；只用邮箱唯一序列 `534D5231 119A0010 42454731 444F4E45 00000001` 判执行完成。
- 仅当 CPU 确认 halted 后，才恢复并 verify 原始 76 字节 scratch；失败或状态未知时停止，不复位、不重试、不改 MMIO/Flash/NVR。

### C. 结果解释

- 邮箱完整匹配且 scratch 恢复：证明该次 canary 的 SRAM 取指/基础指令/邮箱写入路径工作；不证明 I²C/MMIO 正常。
- 镜像 verify 通过但邮箱未变：只证明调试器写 SRAM 通路，不能证明 CPU 取指或执行。
- `resume` PC 读回不匹配、hart 状态异常、或无法安全 halt：立即停止；不得再次 resume，不恢复可能正在执行的代码。
- scratch 恢复失败：记录确切范围和值，停止所有后续外设测试。

## V119A 现场保护状态

V119A marker 和原始日志/preimage 均保留；本轮一次 halt 已发出，SRAM load/resume 为 0。归档目录：
`D:\Obsidian\notes\笔记\beansugar\vibe coding\memory\cy63300自动测试日志\V119A_SRAM_CANARY_20261110`

V119B 不创建 marker、不连接芯片，直到 A 阶段的 PC/DPC 语义审查完成。
