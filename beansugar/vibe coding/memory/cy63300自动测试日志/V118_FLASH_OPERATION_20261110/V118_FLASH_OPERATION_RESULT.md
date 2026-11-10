# CY63300 V118 Flash 写入与运行结果

日期：2026-11-10（Asia/Shanghai）

## 总结

Flash 擦除、V118 编程和独立读回均完成。**V118 从地址 0 的执行未能确认，I²C 传输和 OLED 显示均未通过验证。**本轮没有再次写入或擦除，也没有自动恢复。

## 镜像身份

执行镜像为 1088 字节，地址 `0x00000000–0x0000043F`，SHA256：

`A5BD6B1AC10FF7A7370882BC0AE314624CE2060D70DA821C595C56B92177141D`

这与用户授权的地址范围完全对应。早期报告误将 1080 字节旧构建的哈希写成当前镜像哈希；更正见 `V118_ARTIFACT_IDENTITY_CORRECTION.md`。旧构建未写入芯片。

## Flash 操作事实

1. 第一次擦除触发写在 `0x00000000`。实测只有 `0x00000000–0x000001FF`（512 字节）变为 `0xFF`，V116 数据仍在 `0x200–0x3DB`。执行器因此停止，没有编程。
2. 新阶段重读快照与上述部分擦除状态完全一致后，在 `0x00000200` 触发第二次擦除。随后独立读回的完整 64 KiB (`0x0000–0xFFFF`) 全为 `0xFF`，SHA256=`71189F7FB6AED638640078FBA3A35FDA6C39C8962E74DCC75935AAC948DA9063`。
3. 写入 1088 字节 V118 镜像。OpenOCD 日志包含 `V118_PROGRAM_VERIFY_PASS`、`V118_PROGRAM=PASS`，且无 `Error:`。执行器因错误要求日志必须包含 `verified 1088 bytes` 而误判并停在独立读回之前；原始结果 JSON 保留，未覆盖。
4. 新只读阶段独立读取 `0x00000000–0x0000043F`，内容与镜像逐字节相同，长度 1088，SHA256 与镜像一致。故 V118 Flash 编程和读回已证实成功。

累计：扇区擦除触发 2 次（地址 `0x0` 与 `0x200`）；Flash 镜像编程 1088 字节；NVR 操作 0；其他 Flash 扇区写入 0。

## 执行结果

向 `resume 0` 发出一次执行请求，OpenOCD 报错：

```text
Error: Written PC (0x0) does not match read back value (0x64)
```

没有重试。其后独立只读检查观察到 CPU 初始为 running；执行一次 halt 后为 halted，DMSTATUS=`0x00430382`，SBCS=`0x20040404`。Flash 起始指令与 V118 镜像一致，但 SRAM mailbox 为：

- word 0：`0x00000000`
- word 1：`0x0000600D`
- word 39：`0x9F241934`（旧值/无效值）

V118 要求的 magic `0x4D423138` 和 stage `0x117800D0` 均未出现。因此不能判定 V118 已完成执行，也没有证据表明 I²C FIFO 字节被消耗或 OLED 收到数据。CPU 曾观察为 running 加上 mailbox 缺少唯一标记，意味着可能执行过部分指令，但具体执行到哪一步未知。

该 V118 固件是两字节 OLED 命令探测（`0x00`, `0xAE`），不是显示 `Hello` 的固件；本轮即使执行成功也只能用于检查 FIFO/总线传输进度。

## 主要失败点与后续建议

Flash 写入链路已完成验证；剩余阻碍是当前 OpenOCD/目标组合不能确认 `resume 0` 设置了执行入口，PC 被读回为 `0x64`。V114 曾观察到 DPC 写操作会改变 hart 状态；其参考 RTL 解释不能直接当作流片芯片根因。

下一步不要重烧 Flash，也不要重复 `resume 0`。先离线核对 OpenOCD RISC-V `resume`/DPC 流程与 V118 反汇编中 `0x64` 指令位置，再确定一种不重复 Flash 改写的启动办法。可评估在用户手动上电/复位后由启动向量自然运行 V118，再做只读 mailbox 检查；这一步尚未执行。程序执行和 OLED Hello 都需要新的实物证据。

## 证据与哈希

- V118 镜像 SHA256：`A5BD6B1AC10FF7A7370882BC0AE314624CE2060D70DA821C595C56B92177141D`
- 擦除后完整 64 KiB 快照 SHA256：`71189F7FB6AED638640078FBA3A35FDA6C39C8962E74DCC75935AAC948DA9063`
- V118B 编程日志 SHA256：`E9C51D2F8991D8601B7B280E2AF5132683B642BB9CA92E5331C7DD2588471F3C`
- 独立镜像读回 SHA256：`A5BD6B1AC10FF7A7370882BC0AE314624CE2060D70DA821C595C56B92177141D`
- resume 错误日志 SHA256：`886AFA4E73A16E5EE7F5659F645B5B62D1FB48B214C036D375E9706E229A188E`
- post-resume 只读状态日志 SHA256：`98957B06F96EEC3D239C6AE2525B537AAD7C50BEE66BE2291733A5288318B5FE`
- 所有分阶段原始日志、命令、marker、镜像和结果 JSON 保存在 `runs_local_v118`、`markers` 与本目录中。

