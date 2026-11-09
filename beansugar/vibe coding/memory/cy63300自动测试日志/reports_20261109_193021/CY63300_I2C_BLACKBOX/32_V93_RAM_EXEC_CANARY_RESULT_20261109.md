# V93 RAM 执行 canary 结果

日期：2026-11-09（Asia/Shanghai）  
阶段：`BBX_V93_RAM_CPU_CANARY_01/02/03`

## 结论

**RAM 装载和校验成功，但 CPU 从指定 SRAM 入口执行未获确认。** V93.03 的 `resume 0x20008000` 记录了 OpenOCD 明确错误：

```text
Error: Written PC (0x20008000) does not match read back value (0x2c006dd2)
```

运行后邮箱仍保持原值，未出现 canary 写入的 `MBOX=0x4D424F58 / stage=0x0000CAFE`。OpenOCD 随后的 halt 确认 hart halted，但不能证明它曾从目标地址执行。故本次 CPU 执行结论为 **FAIL/UNKNOWN**，不能把 `load_image` 成功等同于代码运行成功。

## 分阶段记录

| 阶段 | 停止点 | 结果 |
|---|---|---|
| V93.01 | TAP 检查表达式格式不匹配 | IDCODE 已显示正确；RAM 未改、resume 0 次、MMIO 写 0 次。原始日志保留。 |
| V93.02 | 发现 CPU 状态为 running，而脚本要求预先 halted | 按停止条件中止；RAM 未改、resume 0 次、MMIO 写 0 次。原始日志保留。 |
| V93.03 | 单次 halt 后开始 RAM canary | CPU halted、DMSTATUS=`0x00430382`；控制器闲置检查通过；镜像载入并 verify；resume 报 PC 写入/回读不一致；邮箱未变化。 |

V93.03 的执行前控制器读数：`CLKEN=0x21`、`RST=0`、`MODULE_CTRL=0x0F`、`FIFO_STA=0x05`、`I2C_STA=0`、`GPIOB_IDR=0x2C`。这些值证明启动前 I²C FIFO 空、控制器启用且 Pad8/9 读高；不是 canary 执行后的复核。

## SRAM 安全与恢复

- 镜像为 36 字节，入口 `0x20008000`；邮箱 `0x2000F000`。链接脚本和反汇编显示只包含常量装载、两次 RAM store、`fence` 和自循环，没有 MMIO 地址或外设写。
- 运行前保存了代码区 9 个 word 和邮箱 2 个 word，共 11 个 word。
- 程序区与邮箱均恢复为快照值，恢复后逐 word 读回一致，日志 `V93_SRAM_RESTORE=PASS`。
- 目标 MMIO 写入：0；Flash/NVR 写入：0；reset：0。

## 重要解释

1. 可以确认：DAPLink/JTAG 识别正常，hart 可被 halt，DMSTATUS 可读；RAM 镜像可通过 OpenOCD `load_image` 写入并由 `verify_image` 验证；SBA RAM 读写可以用于快照与恢复。
2. 不能确认：CPU 是否曾短暂从错误 PC 运行；因此失败日志后的最终外设状态不能仅凭“脚本没有 MMIO 写命令”推定不变。脚本完成时 hart halted，DMSTATUS=`0x00430382`，SBCS 最终读数=`0x00050000`（其中 OpenOCD 的 SBA 访问配置位已改变；错误位未置位）。
3. V77 的抽象访问曾成功读出 GPR、写入并读回 `x7`，但 Program Buffer `addi` 未执行可见；CPU store SRAM 对照值未变化。V93 新增的错误直接指向 **PC/DPC 设置或读回路径**，应先单独读取当前 PC/DPC并核实 DPC 是否可写，不能再直接重复 `resume address`。
4. V93 结果 JSON 初次解析只给出 `INCOMPLETE_OR_UNKNOWN`，未把日志中的 `Error: Written PC...` 分类为失败；此文件按原执行输出保留。报告中的结论由原始日志人工复核。

## 原始证据

V93.03 目录：`runs/BBX_V93_RAM_CPU_CANARY_03_20261109_151209_518545/`

- OpenOCD 合并日志 SHA256：`B990D795FEFD0E39406BBB4DD7E081AC1ACF389B18133FF6D8729FC9F548862E`
- result.json 日志哈希同上；OpenOCD 返回码为 0 不能代替实际命令结果。
- 标记：`markers/BBX_V93_RAM_CPU_CANARY_03.attempted.json`
- 程序二进制 SHA256：`A315986C21016D6C9D27636F8EC890D5360DED93167C53D0A1B364BCEA494E6B`

## 下一步

先执行新的只读检查：halt（如当前 running 则一次）、读取 `DMSTATUS`、`DPC/PC`、`DCSR`、`SBCS` 及 I²C 空闲寄存器。若状态稳定，再准备一个独立、可恢复的 DPC 抽象写入/读回试验；只有确认 DPC 能被写入目标 RAM 入口，才尝试不带地址的 resume，并在失败时停止。当前不发送 I²C FIFO 数据，避免把尚未建立的 CPU 执行路径与 I²C 问题混在一起。
