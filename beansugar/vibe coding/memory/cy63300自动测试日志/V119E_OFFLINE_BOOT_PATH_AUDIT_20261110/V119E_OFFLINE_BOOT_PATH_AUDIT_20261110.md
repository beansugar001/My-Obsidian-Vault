# CY63300 V119E：离线启动路径核查

日期：2026-11-10（Asia/Shanghai）
范围：只读检查现有 V118 ELF/BIN、反汇编、链接布局与本地参考 RTL；未连接芯片，未运行 OpenOCD，不写 SRAM/MMIO/Flash/NVR。

## 结论

1. V118 ELF 入口地址为 `0x00000000`，链接脚本 `ENTRY(_start)`，`.init` 从 Flash `0x0` 开始；`_start` 先设置栈顶为 `0x20020000`，再调用 `main`（`0xC`）。当前 1088 字节 Flash 镜像已经在此前阶段写入并独立逐字节验证，镜像 SHA256 为 `A5BD6B1AC10FF7A7370882BC0AE314624CE2060D70DA821C595C56B92177141D`。
2. 反汇编在 `0x62` 出现 32 位指令 `lui x14,0x40003`，该指令占 `0x62–0x65`；下一条从 `0x66` 开始。`0x64` 是前一条指令的第二个 16-bit parcel，**不是指令边界，不能作为入口**。ELF 含 RVC，地址半字对齐只满足最低对齐要求，不代表处在合法指令边界。
3. 参考 RTL `core/defines.v` 的 `CpuResetAddr=0`；参考 `debug/jtag_dm.v` 第 252–256 行在抽象 DPC 写时置位 `dm_reset_req`、清除 `dm_halt_req` 并报告 running。其行为可以解释 V119B 的“写 DPC 后 CPU running”，但不证明 ASIC 完全相同。
4. V119B 读回 DPC=`0x64` 后未见 V118 独有 mailbox stage/magic；因此不能断言 V118 正常从 `_start` 跑起来。V119D 后续读到 `FIFO_STA=0xA04`（TX_NUM=10、TX_EMPTY=0），这与 V118 主程序正常路径只写两次 TX FIFO（`0x00` 与 `0xAE`）不匹配。FIFO 计数可能来自错误入口执行、先前状态或芯片/读值行为；当前证据不足以确定来源。
5. 现有证据不支持再试 `resume 0x64`、再次写 DPC 或凭空猜入口。下一步需要取得与流片芯片匹配的 Debug Module/复位启动规范，或让供应方确认 DPC 写是否会触发 reset、复位后实际 PC、是否支持 halt 后设置 DPC/PC 的调试路径。

## 实际离线检查

- `riscv-none-embed-readelf -h cpu_i2c_paced_probe.elf`：ELF32 RISC-V，entry=`0x0`，flags 包含 RVC。
- `riscv-none-embed-objdump -d -M no-aliases,numeric` 输出已保存为 `SRAM_CPU_EXEC_PLAN_20261110/V119_SRAM_CANARY/v118_flash_disassembly_20261110.txt`。
- 自动断言通过：存在 `_start`@0、`0x62` 指令编码 `40003737`，下一条 `0x66` 指令编码 `80c72683`；没有合法指令从 `0x64` 开始。
- 链接 map：`.init=0x0..0xB`、`main=0xC`、`.text` 结束 `0x440`；`.data/.bss` 为空；栈顶 `0x20020000`。这只描述构建布局，不证明运行时 SRAM 状态。
- 参考 RTL `CpuResetAddr=0`，哈希固定在本报告证据表中；这是参考实现证据，不是实物 silicon guarantee。

## 对本轮卡点的解释

DPC 写通过 DMI 抽象命令时，DATA0→COMMAND 顺序正确且 ABSTRACTCS 未报错，但该“命令成功”不等于 DPC 按候选值被写入。目标回读 `0x64` 且 hart running，结合参考 RTL，优先怀疑目标实现把该写路径解释为 reset/run 控制，或 DPC/PC CSR 写语义与 OpenOCD 预期不同。CPU 如果随后从错误 PC 执行，可能产生未预期行为；所以即使日志中 debugger MMIO 写为 0，也不能据此排除 CPU 自主 MMIO 副作用。

V119D 的 `FIFO_STA=0xA04` 解码为 RX_NUM=0、TX_NUM=10、RX_EMPTY=1、TX_EMPTY=0。V118 程序正常路径最多向 TXFIFO 写两次，因此不能把当前 10 项队列归因于“V118 正常发了两个字节”；也不能断言队列是错入口执行导致。需要流片版调试/复位证据及新的可控 CPU 启动方式才能继续定位。

## 下一步准入判断

**停止实物启动操作。** 不执行新的 DPC 写、`resume <address>`、reset、Flash 重写、FIFO 操作或清队列。

可以继续的工作：向公司/芯片供应方询问 DPC 写语义、Debug Module 支持的 PC 设置/启动流程、调试复位后的真实复位向量；离线比对其答复与 V118 启动镜像。只有获得明确且与此芯片版本匹配的流程后，才能设计新的单次实物阶段。当前 CPU 最后一次可确认状态是在 V119D halt 后的只读采样；OpenOCD 会话关闭后没有再次确认其状态。

## 证据文件与 SHA256

| 文件 | SHA256 |
|---|---|
| V118 ELF | `7AAFFF5A4A9B040A067D2B39AB9D6536DBDBE44CBD7D0D5194DBF50458D668F3` |
| V118 Flash BIN | `A5BD6B1AC10FF7A7370882BC0AE314624CE2060D70DA821C595C56B92177141D` |
| 参考 `jtag_dm.v` | `F918FD2BF8BD700DC001894951048CFC2D1D2549B5B010D0AD953229E4A3F543` |
| 参考 `defines.v` | `BEC91DC8796EF2D7475FB813A426B6C71EFE3C2CAEB8FDC9905A1A9101994266` |
| 本次 objdump 输出 | `7D489393646B9CFA20E73B51DD043302B8544845C97BC87918BF786FD225DB20` |
| ELF header 输出 | `8032F7E5FD3C88F35EDE3A061F5BCC7D4341B68A5BA0709113D8E9E77D55F4B3` |
