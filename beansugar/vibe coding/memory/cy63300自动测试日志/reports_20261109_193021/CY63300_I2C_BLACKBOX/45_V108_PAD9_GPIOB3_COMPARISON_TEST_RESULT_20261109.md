# V108 Pad9/GPIOB3 对照测试结果

## 结论

**FAIL / 停止：GPIOB3 的 DIR 释放写入未生效。** 本轮已在目标上执行 3 次 GPIO MMIO 写入；未执行 I²C 控制器配置、START 地址帧或数据帧。不要重跑本阶段，marker 已消费。

## 执行证据

- 阶段：`BBX_V108_PAD9_OD_LOW_RELEASE_01`
- 调试器序列号：`07000001006700343500000a4e57354aa5a5a5a597969908`
- JTAG IDCODE：`0x1E200A6F`；唯一 TAP `riscv.cpu`
- CPU：初始 running；一次 `halt 2000` 后为 halted
- DMSTATUS：`0x00430382`
- SBCS：事务前后均读到 `0x20040404`，未见 busy/error
- PERI_CLKEN：`0x00000001`（GPIO 时钟开，I²C 时钟关）
- PERI_RST：`0x00000000`
- 用户报告 CH2/SDA 空闲约 3.3 V；CH1 接 SCL
- GPIOB 原始值：ODR=0、DIR=0、IDR=0x20、OSOD=0、PUPD=0、AFR1=0、AFR2=0。IDR 的 PB3=0 与示波器 SDA 空闲高电平不一致。

## 目标写入逐笔记录

| 序号 | 写入 | 独立读回 | 判定 |
|---:|---|---|---|
| 1 | `0x40000158 <- 0x00000008`（OSOD bit3） | `0x00000008` | 生效 |
| 2 | `0x40000104 <- 0x00000008`（DIR bit3 输出） | `0x00000008` | 生效 |
| 3 | `0x40000104 <- 0x00000000`（释放为输入） | `0x00000008` | **失败，未恢复** |
| 4 | 未执行 OSOD 恢复 | — | 为避免 DIR 仍为输出时切成推挽，按安全规则停止 |

最后确认的 GPIO 状态：**ODR=0、DIR=0x08、OSOD=0x08**。这表示 Pad9 很可能仍处于开漏拉低配置；实际外部电压需以断电复位后的新只读检查确认。示波器在本次约 1 秒拉低期间是否捕获到低电平尚无用户回报，因此不作波形结论。

## 脚本异常

GPIO DIR 释放写的读回失败后，脚本正确没有再写 OSOD；但 Tcl 的错误分支把 `elseif` 放在新命令行，导致 `invalid command name "elseif"`。因此没有输出 `V108_RESULT` / `V108_COMPLETE`，Python 结果解析为 `INCOMPLETE_OR_UNKNOWN`。这是报告/收尾代码错误，不改变前面三笔目标写入和其读回证据，也不允许重跑已消费阶段。

## 原始材料

- 运行目录：`runs/BBX_V108_PAD9_OD_LOW_RELEASE_01_20261109_192118_272246`
- 完整 OpenOCD 日志 SHA256：`F3E307E90F5C3334FEF105F51EB7CD150799F890FCF3938DFF42B4074E9D9781`
- 执行时 Tcl SHA256：`F2426C2B8CE394663A46008C14263C5C02A6B3878024F69E9DEE4748F7681C2A`
- 执行时 runner SHA256：`1875120FB2A734EDED5420ABE97DBE75F98331308DCAC132353CACAE138F46B2`
- marker：`markers/BBX_V108_PAD9_OD_LOW_RELEASE_01.attempted.json`（保留）

## 立即处置与下一步

1. 目前不要运行任何调试器命令，也不要再次写 DIR/OSOD。
2. 将目标板 Type-C 和 DAPLink 对目标板的供电都断开约 5 秒，再重新接电；这是清除可能仍拉低 SDA 的 GPIO 输出状态。
3. 重上电后另开新阶段，只读确认 `PERI_CLKEN`、`PERI_RST`、GPIOB DIR/OSOD/ODR/IDR；不复用 V108 marker。
4. 修复 Tcl 收尾语法后再讨论新的 Pad9 对照阶段。不能把本轮结果当作 Pad9 电气脉冲成功。

本轮没有 OLED 地址/数据事务，目标 MMIO 写共 3 次，无复位命令、CPU resume、Flash/NVR 操作或自动重试。
