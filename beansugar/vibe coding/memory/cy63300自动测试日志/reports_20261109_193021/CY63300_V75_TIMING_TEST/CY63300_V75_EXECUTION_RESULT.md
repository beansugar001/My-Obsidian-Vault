# CY63300 V7.5 实物执行结果

## 结果

**阶段结果：BLOCKED；目标写入次数：0。**

V7.5 唯一执行入口启动成功并接入了预期 DAPLink，但在 CPU 状态前置检查处停止：`riscv.cpu curstate=running`。脚本要求 CPU 已经 halted，且没有获准发送 halt 请求，因此没有读取 DMSTATUS、SBCS、PERI_RST 或 PERI_CLKEN，也没有发送目标 MMIO 写入。

| 项目 | 实际结果 |
|---|---|
| DAPLink 序列号 | `07000001006700343500000a4e57354aa5a5a5a597969908`，匹配 |
| JTAG IDCODE | `0x1E200A6F`，匹配 |
| 当前 CPU 状态 | `running`；不满足 halted 前置条件 |
| DMSTATUS / SBCS | 未读取；脚本在 CPU 状态检查后立即停止 |
| PERI_RST / PERI_CLKEN | 未读取 |
| 目标 MMIO 写入 | 0 次；`0x4002180C <- 0x20` 未执行 |
| reset / resume / 恢复 / 重试 | 均未执行 |
| OpenOCD 进程返回码 | 0，但任务状态为 `FAIL_OR_UNKNOWN`、无 `V75_COMPLETE`；不得把进程返回码当作阶段通过 |

OpenOCD 启动日志包含 JTAG TAP 层的 `JTAG TLR_RESET`，没有脚本发出的 CPU halt、系统 reset、resume 或 MMIO 写命令。CPU 状态记录为连接检查时观测到的 `running`；本轮未再读取其后状态。

## 阶段记录

- 阶段：`V75_SYSCTRL_DELAY_01`
- 执行时间：2026-11-05 11:14:10–11:14:11（+08:00）
- 阶段 marker：`D:\project\RISCV-63300\CY63300_AUTO_TEST\markers\V75_SYSCTRL_DELAY_01.attempted.json`
- marker SHA-256：`1869FBC9AA31D46AB0AE1D3D18FD9308581A7D2E68DFB4AD1F1CFF106CF71FCD`
- 本阶段已消费，保留原 marker；禁止删除、覆盖或复用。

原始记录目录：

`C:\Users\24796\Documents\组\CY63300_V75_TIMING_TEST\runs\V75_SYSCTRL_DELAY_01_20261105_111410_572206`

| 文件 | SHA-256 |
|---|---|
| `command.json` | `16D5E1A52ED42DACC77F2757C8CFEF880D1835B5D415817310178A0340B8CAD5` |
| `openocd.stderr.log` | `E5C39F4CD300F9E966977639720106A30CF4781112B3D942306866303A314601` |
| `openocd.stdout.log` | `E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855` |
| `openocd.combined.log` | `CBDB88A74F32470260D3C9F2659ED97E209230733127019FF2D0207B2668A037` |
| `result.json` | `DE26C49461A4AC3658070A50865DA845A825AB9F90A0617024330D163B6C851B` |

## 后续建议

V7.5 的时序问题尚未测试。下一步需要一个新的、独立阶段来取得 halted 状态：可以先授权一次 `halt 2000` 并仅做 halted/DMSTATUS/SBCS 只读核验。确认停止状态后，再为一次全新的 V7.5 写入实验单独授权并使用新阶段编号和 marker。当前阶段的写入授权不能延续到新阶段。
