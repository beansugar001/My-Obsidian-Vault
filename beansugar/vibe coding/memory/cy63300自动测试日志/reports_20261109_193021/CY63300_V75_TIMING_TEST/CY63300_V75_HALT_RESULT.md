# CY63300 V7.5 halt-only 阶段结果

**结果：PASS_HALTED_READONLY。** 新阶段 `V75_HALT_READONLY_01` 中，OpenOCD 在 CPU 为 running 时恰好发送一次 `halt 2000`，随后只读核验状态寄存器。

| 项目 | 结果 |
|---|---|
| DAPLink | `07000001006700343500000a4e57354aa5a5a5a597969908` |
| JTAG IDCODE | `0x1E200A6F` |
| halt 请求 | 1 次，`halt 2000` |
| CPU 状态 | `running` → `halted` |
| DMSTATUS | `0x00430382`，halted 状态位符合预期 |
| SBCS | `0x20040404`，idle/error-free |
| 目标 MMIO 写入 | 0 次 |
| reset / resume / retry | 均未执行 |

OpenOCD 会话关闭前最后观察到 CPU 为 halted；没有发送 resume。会话结束后未再次连接核验，因此不把会话关闭后的状态称为再次实测。

阶段 marker 已创建并保留：

`D:\project\RISCV-63300\CY63300_AUTO_TEST\markers\V75_HALT_READONLY_01.attempted.json`

原始日志目录：

`C:\Users\24796\Documents\组\CY63300_V75_TIMING_TEST\runs\V75_HALT_READONLY_01_20261105_112044_409112`

- `openocd.stderr.log` SHA-256：`60CE6BB66830C5A7A03C1D2DEB4FC3A25C375D7E2BCF3627925452AA3C05486C`
- `openocd.combined.log` SHA-256：`9C2346A20E1DBFAC41180D2BDAA9933CACB46F1FC3F06C7AB0928E72A06F11D7`
- `result.json`：`PASS_HALTED_READONLY`，halt 计数 1，目标写计数 0。

下一阶段可以在新 marker 下重新准备 V7.5 的那一次 `0x4002180C <- 0x20` 实验。原 `V75_SYSCTRL_DELAY_01` marker 已消费，且此前授权对应的阶段已结束；新的目标写入仍需单独授权。
