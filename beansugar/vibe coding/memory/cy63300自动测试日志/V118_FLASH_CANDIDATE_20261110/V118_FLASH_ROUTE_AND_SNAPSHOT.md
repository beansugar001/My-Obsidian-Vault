# V118：Flash 驻留测试候选与实物只读核验

日期：2026-11-10（Asia/Shanghai）

## 结论

已完成 Flash 驻留方案的离线构建，并对实物主 Flash 的第 0 扇区做了一次 64 KiB 只读快照。**本轮没有写入或擦除 Flash，没有执行程序，也没有目标 MMIO 写入。**

当前 V116B 镜像仍准确位于 Flash `0x00000000–0x000003DB`：实物读取的前 988 字节与已验证 V116B binary 逐字节一致（不匹配字节数=0）。读取的扇区快照为 65536 字节，SHA256=`E1F99E6A8F8D6D139DA06D6D288E9E00BBD9E6C7A6185B56B33C3A5CBA39D9E7`。

新的 V118 候选镜像长 1088 字节，链接入口 `0x00000000`，末地址 `0x0000043F`。与实物当前内容逐字节比较，目标镜像中有 **736 个字节需要 0→1 转换**，不能只用 Flash 编程模式完成，必须先擦除包含这些地址的扇区。

## 本轮只读实物核验

- 阶段：`BBX_V118A_FLASH_READONLY_SNAPSHOT_20261110_01`
- 唯一 TAP IDCODE=`0x1E200A6F`
- 指定 DAPLink 序列号匹配：`07000001006700343500000a4e57354aa5a5a5a597969908`
- OpenOCD 退出码=0；日志没有 `Error:`；快照长度=65536
- 前 988 字节与 V116B 已验证 binary 不匹配数=0
- 目标 MMIO 写入=0；Flash 写入=0；Flash 擦除=0；NVR 操作=0；CPU reset/resume=0
- marker：`markers\BBX_V118A_FLASH_READONLY_SNAPSHOT_20261110_01.attempted.json`
- 运行目录：`runs_local_v118\BBX_V118A_FLASH_READONLY_SNAPSHOT_20261110_01_20261110_141047_161`
- 合并 OpenOCD 日志 SHA256：`A86E474D33D32F0295357B4F600B916246D2B238E5C88187AB12FA96105D6C9B`
- 扇区快照 SHA256：`E1F99E6A8F8D6D139DA06D6D288E9E00BBD9E6C7A6185B56B33C3A5CBA39D9E7`

## Flash 候选构建

候选程序基于 V117 的 ARM-paced CPU-store OLED 探测流程。相对 SRAM 版，只将链接入口换为 Flash `0x0`，并将 mailbox 改为本阶段独有：开始 stage=`0x11780001`，完成 stage=`0x117800D0`，magic=`0x4D423138`。这样可防止把 V116 遗留的 `MBOX/0x600D` 误作本轮成功。

- 文件：`cpu_i2c_paced_probe_flash.bin`
- 大小：1088 字节
- 地址范围：`0x00000000–0x0000043F`
- ELF 入口：`0x00000000`
- binary SHA256：`D9A45D25C80E1DE6FDEAE83680CC254A2BD3910FA68CE96A48745D643FB49FB9`
- ELF SHA256：`A215BA98DE5834711E19347AA3D03D7CF853E5CBC6B7C2D8D3837DD397429319`
- C 源码 SHA256：`A15FD835F4D0CE8F3F2E86874C2B9C16E9D20CB84BFE47BD7D0EC9F4C65F811C`
- map SHA256：`C68F95CB9D96477785889577C2A540804FF513FB1E8B14EF927795A5D30D100D`

## 擦写范围与风险

《CY63300 数字电路设计说明》A0 的 Flash 空间表将 main/system sector 0 定义为 `0x00000000–0x0000FFFF`（64 KiB）；sector 1 为 `0x00010000–0x0003FFFF`（192 KiB）。文档的 Flash 擦除流程要求设置 `FLS_CR.ser_en`，再向该扇区内地址写入以触发扇区擦除；`rwe_sel=2` 是 sector erase 模式。因此，替换当前入口固件的候选操作会擦除整个 64 KiB sector 0，而非只擦 1088 字节。

现有 256 KiB 烧录前备份全为 `0xFF`（SHA256=`3B874D3BA46C638FC3094F8E92FB744CA974893873F8885F54E23760F9B6311B`）。同时，当前实物 sector 0 的前 988 字节与 V116B binary 相符。擦除/编程中断会让芯片暂时没有可启动测试固件；可用的恢复文件是 V116B 988 字节 binary，但恢复它也需要在已擦空的 sector 0 编程，并且恢复结果需重新读回验证。NVR 不在本候选范围，任何操作都不得触及 NVR。

工程目录 `D:\project\RISCV-63300\AGENTS.md` 明确禁止 Flash 擦除、`rwe_sel=2/3` 和向 `0x00000000` 写固件。用户已明确授权 Flash 写入，但尚未明确批准本次特定的 **64 KiB sector 0 擦除**。因此本报告只作为候选和审查材料，未触发任何擦写。

## 建议的下一阶段（等待单独明确批准）

若决定执行，阶段应明确限定为：先检查 JTAG/IDCODE 和指定探针，读回并保存 sector 0 当前 64 KiB；随后只擦除 sector 0 `0x00000000–0x0000FFFF`，只编程 V118 binary `0x00000000–0x0000043F`，读回校验镜像及擦除范围，检查唯一 mailbox stage，再观察 I²C/SCL/SDA。不得碰 sector 1 或 NVR；任一步出错立即停，不自动恢复、不重试、不复位。V116B 988 字节镜像仅作为独立恢复候选，恢复也须另行授权。

## 关键证据路径

- 实物快照及命令/日志/marker：`runs_local_v118\BBX_V118A_FLASH_READONLY_SNAPSHOT_20261110_01_20261110_141047_161`
- 离线候选源码、ELF、map、binary：本目录
- 数字设计说明摘录：`D:\project\RISCV-63300\_analysis\design_doc_full.txt`，§3.3.1 Flash sectors；§4.5.2.3 page/sector erase；§4.5.3.1 `FLS_CR.rwe_sel`
