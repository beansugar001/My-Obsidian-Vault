# CY63300 V119B：DPC 门控 SRAM 启动实测结果

日期：2026-11-10（Asia/Shanghai）
阶段：`BBX_V119B_SRAM_DPC_GATED_START_20261110_01`

## 结论

**SRAM 程序执行仍未证实。** OpenOCD 对 SRAM canary 的写入和镜像校验通过；随后只发出一次 DPC 抽象 CSR 写，写后 DPC 读回却是 `0x00000064`（期望 `0x20008000`），hart 从 running 起始状态经 halt 后重新进入 running。脚本检测到 hart 已运行，因此没有再发 `resume`。最终邮箱仍是旧值 `00000000 0000600D 00000000 00000000 00000000`，未见 V119B 标记。

代码区和 mailbox 区都已在 halt 确认后恢复并 verify。未发生目标 MMIO、Flash/NVR、reset、断电或额外 resume。

## 实际过程与状态

| 项目 | 结果 |
|---|---|
| DAPLink 序列号 | `07000001006700343500000a4e57354aa5a5a5a597969908` |
| JTAG TAP / IDCODE | 唯一 `riscv.cpu` / `0x1E200A6F` |
| JTAG 速度 | 100 kHz |
| 初始 hart | running；发送一次 `halt 2000` 后 halted |
| DMSTATUS / SBCS（写前） | `0x00430382` / `0x20040404` |
| DPC / DCSR / MISA（写前） | `0x00000001` / `0x000000C0` / `0x70000000` |
| SRAM canary | 76 字节写入 `0x20008000` 并 `verify_image` 通过 |
| DPC 写入 | 一次：`0x7B1 <- 0x20008000`，抽象命令的 `ABSTRACTCS=0x01000003` |
| DPC 读回 | `0x00000064`，与目标入口不符 |
| DPC 写后的 hart | running；未发 no-argument resume；之后只 halt 一次 |
| 邮箱 | 未匹配：读回仍为旧值 `00000000 0000600D 00000000 00000000 00000000` |
| 写后 DMSTATUS / SBCS | `0x00430382` / `0x00150000`；脚本按当前位掩码未判 busy/error，但 SBCS 与写前基线不同，需后续解释，不能把它当作事务提交证明 |
| 恢复 | `0x20008000..0x2000804B` 76 字节和 `0x2000F000..0x2000F013` 20 字节均恢复并 verify 通过 |
| 目标 MMIO / Flash/NVR | 0 / 0 |
| resume / reset / 断电 | resume 0；reset 0；断电 0 |

## 根因判断

1. **不是“忘记先请求再写”的顺序问题。** 本轮 DPC 操作按 OpenOCD 抽象寄存器访问顺序执行：先把候选值写入 DMI `DATA0`，再向 `COMMAND` 发出 `transfer=1, write=1, regno=DPC`，随后检查 `ABSTRACTCS` 并独立读取 DPC。抽象命令结束状态正常，但目标 DPC 值没有保持为写入值。
2. **镜像装载路径与 CPU 执行路径必须分开看。** `load_image` + `verify_image` 证明调试器的 SRAM 写入/回读路径可工作；邮箱不变说明这次没有获得 CPU 从 `0x20008000` 执行 canary 的证据。
3. **DPC 写入产生了额外状态变化。** 实物观察是 DPC 写之后 hart 变为 running，而 DPC 读回是 `0x64`。这更符合芯片调试模块对 DPC 写/恢复请求有自定义副作用，或 DPC/PC 访问语义与通用 OpenOCD 假设不同；当前证据不足以断言它具体从 `0x64` 取指，也不足以认定 CPU 已从 SRAM 起跑。
4. **写后 SBCS 发生变化。** `0x00150000` 的字段解释还需对照本芯片实现和寄存器定义；不能把它直接称为 SBA 错误，也不能只凭抽象命令成功推断 SRAM/CPU 动作已提交。

## 安全与现场状态

- 全局 marker 已创建并保留；本阶段不可重跑。
- 未复用 V119A marker，未覆盖 V119A 日志。
- 运行目录：`C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX\runs_local_v119\BBX_V119B_SRAM_DPC_GATED_START_20261110_01_20261110_153714_287525`
- marker：`C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX\markers\BBX_V119B_SRAM_DPC_GATED_START_20261110_01.attempted.json`
- 原始合并日志 SHA256：`612ECBB375F0CD7E49E575E789BA7032852C8C64607038290B47C0E0191DA8D0`
- OpenOCD stderr SHA256：`E87FBD45F76326C79261A0408A993A8E01F79B6EE71B44DC8FE9BF3748056669`
- canary BIN SHA256：`E53B8FEACE6CBCB573A4DE242F870567ACEEFBED3A202C7A96671DF5282FA971`
- Tcl SHA256：`DCC6ACE6FB5B7CAC2897C9A051DB924D3E707E21D93BB26DCB77777C158B8817`
- Python runner SHA256：`4EBDF454C7467E81993A15E1E1F79C11675214DA9978A4BB7CB6997B5787A44C`
- 配置 SHA256：`1275374EA7E2E976B7E0F86D48EE2E9389C344B4A8C36D38F215D5E1D36656B4`

## 下一步

先停止新的 DPC 写入和 SRAM 启动尝试。下一步应离线对照《数字设计说明》、可用的 `jtag_dm.v`/CPU debug RTL、`0x64` 的 memory map / boot vector 和 V114/V119B 原始日志，确认：

- DPC 抽象写是否应更新 DPC，还是在该芯片上会触发 debug reset/run；
- `0x64` 是启动向量、异常入口还是异常/旧值；
- 写后 SBCS `0x00150000` 的字段含义；
- 若 DPC 路径无法设 PC，是否存在受支持的 hart reset-halt、debug ROM 或启动地址配置路径。

只有找到一个不会绕过 DPC/DM 安全门、且可独立验证入口地址的启动方式后，再准备新的 SRAM 执行阶段。不要把这次结果表述为 CPU 已执行 SRAM 或 I²C 已恢复。
