# V119A SRAM Canary 执行结果与阻断说明

日期：2026-11-10（Asia/Shanghai）

## 结论

V119A 连接并识别了目标，CPU halt 成功；但测试脚本在 SRAM 写入之前因 Tcl 字符串变量插值错误而中止。**没有加载 canary、没有执行 resume、没有写 MMIO/Flash/NVR。**

读到的 DPC 为 `0x00000001`（两次一致），不满足 32-bit 指令地址对齐；MISA 为 `0x70000000`（两次一致，也与本项目历史值不同）。这两个读数本身不能证明芯片损坏，但意味着当前 PC/DPC 访问语义仍未解释。按照既有 V119 离线准备报告中的停止条件，不应继续将 canary 写入并 resume。

## V119A 实际结果

- DAPLink 序列号：`07000001006700343500000a4e57354aa5a5a5a597969908`
- JTAG IDCODE：`0x1E200A6F`；唯一 TAP `riscv.cpu`
- CPU 起始为 running；发送一次 `halt 2000` 后读到 halted
- DMSTATUS：两次 `0x00430382`
- SBCS：`0x20040404`，未见记录的 busy/error 标志
- DPC：两次 `0x00000001`
- DCSR：两次 `0x000000C0`
- MISA：两次 `0x70000000`
- SRAM scratch 旧内容已保存至原始 76-byte preimage 文件
- 失败点：`can't read "label_BEGIN": no such variable`
- 日志没有 `V119_CANARY_LOAD_BEGIN` 或 `V119_RESUME_REQUESTS=1`
- `SRAM_LOADED=0`，因此没有 SRAM 修改，也不需要恢复 preimage
- 目标 MMIO 写入 0；Flash/NVR 写入 0；复位 0；resume 0
- 本阶段 marker 已消费并保留：`BBX_V119A_SRAM_CANARY_20261110_01.attempted.json`

### 日志证据

运行目录：
`C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX\runs_local_v119\BBX_V119A_SRAM_CANARY_20261110_01_20261110_150557_625005`

- combined log SHA256：`426F620F21216070B67566B561AFA93B142A4FBFAD0C4A43FC07835A18109752`
- stderr log SHA256：`F4D6A9B5596371EFCCF109CBAC860CB9B68C1F878277864D8F071F5E08615479`
- stdout log SHA256：`E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855`
- SRAM preimage SHA256：`050AD1601BE596AE0ACD9CAE5DE52CDD59DB42D1448BE2BD868B21F4ACFBC100`

## 离线修正

1. 修复 `v119_read_mem` 的 Tcl 动态变量名问题：使用 `format` 生成 `V119_MEM_<label>_BEGIN/END`，避免 Tcl 将 `$label_BEGIN` 解释为另一个变量。
2. 将 `v119_sram_loaded=1` 放在 `load_image` 之前，保证若加载中途失败，脚本也会进入有条件的恢复路径。
3. 新增 DPC 对齐停止门：非 4-byte 对齐时，在任何 SRAM 写入前终止。当前读数 `0x1` 会触发该门。
4. 离线检查通过：Tcl `info complete`、Python 编译、必要停止门和恢复标志顺序检查均 PASS。

当前脚本 SHA256：`EB4CE30A45A9C10EC3CF565D219E0E3BADDADB086946177BAD0E9B053F95141A`
当前 runner SHA256：`00222BD57BBD689A9F38E4B19B6D89ED50A4E1B8846A543D051056DE98EC24BA`

## 下一步

先查清 OpenOCD `resume` 对 DPC/PC 的写入与读回路径，并核对芯片当前稳定读数 `DPC=1`、`MISA=0x70000000` 的含义。已有离线准备报告指出，V93/V117C 曾发生 PC 写回不匹配，V95 DPC 写读未成功，V114 观察到 DPC 操作可能改变 hart 状态；参考 RTL 的行为不能直接当作流片芯片结论。

完成该审查前，不运行 V119B 硬件入口，不写 SRAM，不 resume。V119A 的 marker、原始日志和 preimage 均保持原样，V119B 使用全新阶段名和 marker。

