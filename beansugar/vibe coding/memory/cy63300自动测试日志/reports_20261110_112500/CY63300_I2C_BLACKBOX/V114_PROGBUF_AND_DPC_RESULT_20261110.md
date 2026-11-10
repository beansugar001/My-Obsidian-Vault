# CY63300 V114：CPU 单指令绕过路径验证结果

日期：2026-11-10（Asia/Shanghai）

## 结论

V114 没有执行 `addi`，更没有向 I²C FIFO 执行 CPU store。DMI 写入 `PROGBUF0` 后再读回仍是 `0x00000000`，脚本按预先定义的安全门槛在 postexec 前停止。随后脚本恢复了 x7 和 DPC，但最终 `DMSTATUS` 变为 running；这暴露了 DPC 写回会改变 hart 状态的风险。V114B 通过一次 halt 请求重新取得 halted；下一次 OpenOCD 会话 V114C 又观察到 running，因而停止且没有读取 I²C 寄存器。

当前 I²C 状态不能沿用 V113A5 的读数当作最新状态。最新完整 I²C 快照仍是 V113A5，但其后曾出现 hart running；V114C 为避免在 running 时扰动目标而没有做任何 MMIO 读取。**不再追加 I²C 配置写入；需先重新上电清场，再从新基线开始。**

## V114 实物记录

| 项目 | 结果 |
|---|---|
| DAPLink | 序列号 `07000001006700343500000a4e57354aa5a5a5a597969908` |
| JTAG | 唯一 TAP `riscv.cpu`；IDCODE=`0x1E200A6F`；100 kHz |
| CPU | 初始化时 running；一次 `halt 2000` 后 halted；DMSTATUS=`0x00430382` |
| 调试能力 | ABSTRACTCS=`0x01000003`，报告 `progbufsize=1` |
| Program Buffer | DMI 读写前读回 `0x00000000`；写 `addi x7,x7,1` 后仍读回 `0x00000000`，因此 **postexec 次数=0** |
| 状态恢复 | x7 写回并独立读回一致；DPC 写回后读回一致；Program Buffer 请求写入 NOP |
| 最终 hart 状态 | DMSTATUS=`0x00430C82`（running） |
| 目标副作用 | SRAM/MMIO/Flash/NVR 写入=0；I²C MMIO 读取=0 |
| 合并日志 SHA256 | `28A3715BF0271A04B991114D36162B4F11DAABA468AE50ECCE2113AE4DA5ECEC` |

V114B 使用独立阶段发送一次 halt 请求，读到 CPU halted、DMSTATUS=`0x00430382`，目标 MMIO/内存写入为 0；合并日志 SHA256：`6D1878FB4C3429F9BAF231177EA904FDC2C2E5A9D72D3504978C8A6E4655D548`。之后新的 V114C 会话在初始化时观察到 CPU running；按门禁立即退出，I²C 读数=0、写入=0；合并日志 SHA256：`951E32D6F5F35CDDB4D7AFC64322C45A253D49785C3189A8DABCC7B991CAD7DA`。

## 对照参考 RTL

可用的参考快照为 [jtag_dm.v](D:/project/RISCV-63300/CY63300_AUTO_TEST_V60/snapshots/reference_rtl/debug/jtag_dm.v)，SHA256=`F918FD2BF8BD700DC001894951048CFC2D1D2549B5B010D0AD953229E4A3F543`。

- DMI 读取的 `default` 分支返回 0（约 196–198 行）；该实现没有 PROGBUF0 的读寄存器分支。
- COMMAND 处理只实现抽象寄存器访问；当 postexec 位 `data[18]` 为 1 时，没有对应的 Program Buffer 执行分支（约 233–264 行）。
- 写 DPC 分支会置 `dm_reset_req`、清 `dm_halt_req`，并把 DMSTATUS 的 running 位设起（约 252–256 行）。这和 V114 中 DPC 写回后看到的 running 状态相符。

这说明所提供的参考 RTL 能复现“PROGBUF 读零、postexec 无效果、写 DPC 后转为 running”的模式；它不是流片 ASIC RTL，故只能解释现象、不能单独证明芯片内部实现完全相同。

## 对 I²C 根因的影响

1. 之前的 SBA FIFO 写已把 `TX_NUM` 从 0 增到 1，说明数据进入 TX FIFO 的 MMIO 写路径曾生效；但控制器没有把该字节消费掉。
2. V114 证明当前依赖的 DMI Program Buffer/CPU-store 对照路径未能确认执行。因此，不能用“CPU store 与 SBA store 对照”直接排除 SBA；也不能把它当作已经准备好的替代方案。
3. ARM 轮询样例里的“先请求地址”是 `I2C_SetAddr(target)`，然后 enable，再写 payload 字节；`0x78` 是 OLED 地址 `0x3C` 对应的线上地址字节，不是该样例传给 `I2C_WrByte()` 的普通 payload。V113A3 已按地址预置顺序进行过一次，仍卡在 TX_NUM=1、WORK=1、DATA=0、RAW=0。
4. 唯一明确的文档分歧仍是 RISC-V 设计说明把 `I2C_ADDR` 描述为 I2CS address，而 ARM 主机驱动实际把它用于 `I2C_SetAddr(target)`。仅靠 ARM 驱动的读写 API 尚不能消除这项芯片版本/文档差异。

## 下一步

先由用户完整断开目标板电源和调试器连接数秒后重新接回，确保 FIFO 和控制器状态从干净启动开始。后续新阶段先取得只读基线。由于 CPU 执行绕过未建立，下一项需要优先取得“总线是否真的出现 START/SCL/地址 ACK”的独立证据；可以用示波器在 Pad8/SCL、Pad9/SDA 捕获，或先询问公司工程师确认 RISC-V `I2C_ADDR`/TX_FIFO 首字节的主机帧格式。不要再重复 V113A3 的相同配置顺序，也不要在未重新上电的现场继续写 FIFO、MCTR 或 MODULE_CTRL。

## 归档

- V114、V114B、V114C 三个阶段日志、命令/结果 JSON、marker、脚本和 Tcl 已分别保留在工作区 `runs_local_v109` 与 `markers`。
- 本报告及原始证据副本归档至 Obsidian：`D:\Obsidian\notes\笔记\beansugar\vibe coding\memory\cy63300自动测试日志\reports_20261110_112500\CY63300_I2C_BLACKBOX`。
