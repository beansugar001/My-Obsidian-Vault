# V118 镜像身份更正

日期：2026-11-10（Asia/Shanghai）

在执行 Flash 操作前的哈希复核中发现，`V118_FLASH_ROUTE_AND_SNAPSHOT.md` 中镜像长度和 SHA256 来自两个不同构建：

| 构建 | 长度 | 地址范围 | SHA256 | 说明 |
|---|---:|---|---|---|
| 早期候选 | 1080 B | `0x00000000–0x00000437` | `D9A45D25C80E1DE6FDEAE83680CC254A2BD3910FA68CE96A48745D643FB49FB9` | 没有 V118 独有 mailbox magic/stage |
| 当前候选 | 1088 B | `0x00000000–0x0000043F` | `A5BD6B1AC10FF7A7370882BC0AE314624CE2060D70DA821C595C56B92177141D` | mailbox start=`0x11780001`，complete=`0x117800D0`，magic=`0x4D423138` |

当前文件 `cpu_i2c_paced_probe_flash.bin` 是第二个 1088 B 构建，与用户授权的 `0x00000000–0x0000043F` 范围相符。早期 1080 B 候选未获准替代它；两者内容不同。

由于首个 64 KiB Flash 扇区需要擦除，镜像内容身份必须明确。发现不一致后停止了硬件操作；截至本报告，V118A 只读快照仍是最近一次 Flash 实物状态，V118 阶段没有发生 Flash 擦除、Flash 编程、CPU resume 或目标 MMIO 写入。

实际候选产物：

- Binary：`cpu_i2c_paced_probe_flash.bin`，1088 B，SHA256=`A5BD6B1AC10FF7A7370882BC0AE314624CE2060D70DA821C595C56B92177141D`
- ELF：`cpu_i2c_paced_probe.elf`，SHA256=`7AAFFF5A4A9B040A067D2B39AB9D6536DBDBE44CBD7D0D5194DBF50458D668F3`
- C source：`cpu_i2c_paced_probe.c`，SHA256=`A15FD835F4D0CE8F3F2E86874C2B9C16E9D20CB84BFE47BD7D0EC9F4C65F811C`
- Linker map：`cpu_i2c_paced_probe.map`，SHA256=`C68F95CB9D96477785889577C2A540804FF513FB1E8B14EF927795A5D30D100D`
