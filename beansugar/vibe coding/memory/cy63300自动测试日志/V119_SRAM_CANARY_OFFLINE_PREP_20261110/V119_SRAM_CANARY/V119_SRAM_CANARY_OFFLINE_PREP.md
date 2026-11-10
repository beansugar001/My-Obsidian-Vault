# V119 SRAM Canary：离线准备结果

日期：2026-11-10（Asia/Shanghai）

## 状态

- **离线 canary 编译：PASS**
- **入口/链接布局静态核对：PASS**
- **OpenOCD PC/DPC 底层路径审计：BLOCKED（本机项目目录未找到对应源码；无目标配置的 help 调用没有给出 resume 细节）**
- **真实目标执行：未进行**

本轮未连接 DAPLink/芯片，未调用带目标配置的 OpenOCD，未写 SRAM/MMIO/Flash/NVR，未 halt、resume、reset 或断电。

## Canary 内容

新建 `V119_SRAM_CANARY` 最小汇编程序：

- ELF 入口：`0x20008000`
- BIN 大小：76 字节
- 编译目标：RV32I、无压缩指令、无 relaxation、无运行库
- 栈顶：`0x20020000`
- 运行时只向邮箱 `0x2000F000` 写入以下本轮唯一序列，然后在 SRAM 内循环：
  - word0 magic `0x534D5231`（SMR1）
  - word1 stage `0x119A0010`
  - word2 started `0x42454731`（BEG1）
  - word3 done `0x444F4E45`（DONE）
  - word4 completion count `1`
- 源码不含 I²C、GPIO、其他 MMIO、Flash/NVR 或 UART 访问。

源码：[sram_canary.S](sram_canary.S)；链接脚本：[sram_canary.ld](sram_canary.ld)；反汇编：[sram_canary.disasm.txt](sram_canary.disasm.txt)；映射：[sram_canary.map](sram_canary.map)。

## 编译与静态核验

使用本机 `riscv-none-embed-gcc 8.3.0` 编译成功。ELF 检查为 ELF32/RISC-V，入口严格为 `0x20008000`；反汇编从入口开始每条 4 字节，代码总长 `0x4C`。邮箱映射与代码段不重叠，栈顶位于 SRAM 高端。

关键 SHA256：

| 文件 | SHA256 |
|---|---|
| `sram_canary.S` | `504808D7DE3C9314BD5D0763ED2657898ED89B5934DCA51F3C4D06EF2B2D89E1` |
| `sram_canary.ld` | `98610D664AEB4726497B2A3C6118C558FED983CC5F985149ABDFAC41D6F5E4A4` |
| `sram_canary.elf` | `AC860976FEA9FB49BF43B67E713EF42E953E1D88D9238EEBF6ECC0F06768F0EE` |
| `sram_canary.bin` | `E53B8FEACE6CBCB573A4DE242F870567ACEEFBED3A202C7A96671DF5282FA971` |
| OpenOCD binary | `EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27` |

完整构建脚本为 `build_canary.ps1`，编译产物和散列保存在本目录。

## 重要的历史结果更正

V117C 的旧 `result.json` 曾报告 `SRAM_PROGRAM_EXECUTED`。原始日志实际包含 `Written PC (0x20008000) does not match read back value (0x0)`；之后读到的是旧 V116 mailbox `MBOX/0x600D`。应采用已有 `V117C_SRAM_EXECUTION_FAILURE.md` 与 `result_audit.json` 的更正结论：V117C 没有证明 CPU 执行 SRAM。

## 阻断原因与下一步

V93、V117C 的 SRAM resume 都有 PC 写回不匹配；V95 的候选 DPC 写入也未读回成功，V114 还观察到 DPC 操作会改变 hart 状态。本机现有 OpenOCD 是 0.10.0 二进制，当前可访问的工程目录中没有对应的 `riscv.c` / `riscv-013.c` 源文件。无目标配置的 `help resume` 调用没有输出 resume 细节。**因此还没有解释清楚目标的 PC/DPC 操作语义，不应把新 canary 送入芯片重复撞同一阻断点。**

下一步先拿到与此 OpenOCD 构建匹配的源码/补丁，或让芯片供应方确认 Debug Module 的 DPC 写入、halt/resume 与 PC 回读语义；离线核对之后再提交一次受控 SRAM canary 实测授权。此 canary 若执行，成功只证明 CPU 能从 SRAM 取指、执行基础指令并写邮箱，不代表 CPU MMIO/I²C/OLED 成功。
