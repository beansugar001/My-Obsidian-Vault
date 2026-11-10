# V117C SRAM 执行失败审计

日期：2026-11-10（Asia/Shanghai）
阶段：`BBX_V117C_SRAM_ARM_PACED_OLED_20261110_01`

## 结论

本轮**没有执行 SRAM 中的测试程序**，因此没有进行新一轮 I²C 初始化、软复位或 OLED 字节发送。

- 1208 字节镜像通过 `load_image` 和 `verify_image` 写入并验证到 SRAM `0x20008000`。
- 随后的 OpenOCD `resume 0x20008000` 报错：`Written PC (0x20008000) does not match read back value (0x0)`。
- 因 PC 未能设置到 SRAM，CPU 没有被证明从该镜像开始执行。
- 之后读到的 mailbox `MBOX / 0x600D` 与 V116B 固件格式相同，且没有 V117C 唯一启动/完成标记；它是旧数据，**不能作为本轮程序完成证据**。
- OpenOCD 外层退出码为 0，但这不改变上述执行失败。原 `result.json` 将状态写成 `SRAM_PROGRAM_EXECUTED`，并将旧 mailbox 误判为完成，属于结果解析器假阳性。原文件保留不覆盖，本报告作为更正记录。

## 实际执行证据

硬件连接与初始化通过：DAPLink 序列号 `07000001006700343500000a4e57354aa5a5a5a597969908`，唯一 TAP，IDCODE `0x1E200A6F`，100 kHz。CPU 初始为 running；一次 halt 后确认 halted。DMSTATUS=`0x00430382`，SBCS 初值=`0x20040404`。

加载 SRAM 程序前读到：PERI_CLKEN=`0x21`、PERI_RST=`0`、MODULE_CTRL=`0x0F`、FIFO_STA=`0x204`、I2C_STA=`1`、RAW_INTR_STA=`0`、MCTR=`2`。这些与 V116B 的残留/重放状态一致。

唯一执行错误原文：

```text
V117C_SRAM_VERIFY_PASS
V117C_RESUME_SRAM address=0x20008000
Error: Written PC (0x20008000) does not match read back value (0x0)
```

随后 mailbox 仍为 `4d424f58 0000600d`，这与 V116B 标志相同，不是 V117C 的唯一标志。最终 SBCS=`0x00150000`；该值不能证明 SRAM 程序执行成功。OpenOCD 记录的目标 MMIO 写入数为 0；本轮确有 SRAM 镜像写入/校验，未写 Flash/NVR。

## 解析器缺陷与证据完整性

1. Tcl 仅检查 mailbox 中通用的 `MBOX` 和 `0x600D`，未校验 V117C 专属 magic/stage，因此把旧 mailbox 当作成功。
2. `resume` 的 OpenOCD 命令错误未被 Tcl `catch` 捕获；错误后脚本仍继续读邮箱并输出成功状态。
3. 外层返回码 0 被当作阶段完成条件，忽略日志中的 `Error:`。
4. V117C 的 `result.json` 原样保留。纠正判定另存为 `result_audit.json`，不得覆盖原始日志或 marker。

## 与既有 V114 证据的关系

V114 报告已记录 `progbufsize=1`，PROGBUF 写入读回为 0，因此未执行指令；并观察到写 DPC 后 hart 变为 running。参考 `jtag_dm.v` 的 DPC 写入路径会触发 `dm_reset_req` 并改变 hart 状态，但它只是参考 RTL，不能证明流片芯片内部实现。V117C 的 PC 写入后读回 0 与当前无法通过 OpenOCD 将执行入口交给 SRAM 的现象一致；根因尚未定位到真实芯片的具体内部层级。

## 产物哈希

- 合并原始日志：`F7B1AB0E8681A00B58F13C355F7913BE5DA6EC8D4137135ED26EB1A58A8BA1C1`
- stderr：`772E673F06E912207AB0A4F1409BA1834C2141F3A32B9FFA48E94DB7EFEB0B0C`
- 原始 `result.json`：`4909DD171BADFF7878A2657BBCFFDA335C336A4FD79BD54F219E5C95AA1A65A0`
- SRAM binary：`A1A4D6029CDE6FA2D51495A5E3227757F44FFC15608A4FBEF94E4873504E7144`
- Tcl：`289E8A98C7B0E5193D3BA82D7C5550942EA2164E29D47509D95882E422E746F4`
- 先前 V114 报告：`reports_current\V114_PROGBUF_AND_DPC_RESULT_20261110.md`

## 当前判断与下一步

**已证明：** 当前调试链可把镜像写入 SRAM 并读回校验；这只证明 SRAM 写路径，不证明 CPU 能从 SRAM 执行。

**未证明：** CPU 从 SRAM 取指、执行 CPU store、I²C FIFO 消耗、SCL/SDA 波形及 OLED 显示。

下一步先停止重复执行同一 `resume`。先离线修正执行器：每次阶段使用唯一 mailbox magic/stage；任一 Tcl 命令错误、日志含 OpenOCD `Error:`、PC 回读不等于入口或完成标记缺失，都必须将阶段判为失败且不再读旧 mailbox 作成功判断。随后要继续 CPU-store 对照，必须先确定一个可支持的程序执行入口。V114/V117C 表明当前 SRAM 入口路径未建立。

另一条可能路线是 Flash 驻留程序，但它会涉及地址 0 附近现有固件及可能的 Flash 擦除/改写。`D:\project\RISCV-63300\AGENTS.md` 当前明确禁止 Flash 擦除和向 `0x00000000` 写入固件；本轮没有执行任何 Flash 修改。只有先核实擦写粒度、备份恢复方法和具体变更范围，并取得针对该操作的明确授权，才能考虑这条路线。

## 文件位置

原始运行目录：
`C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX\runs_local_v116\BBX_V117C_SRAM_ARM_PACED_OLED_20261110_01_20261110_135751`

本报告不替代原始日志与 marker。
