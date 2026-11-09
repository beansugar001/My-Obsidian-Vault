# V8.8G–I：按 ARM 顺序初始化并进行 OLED 最小命令帧测试

日期：2026-11-05（Asia/Shanghai）

## 结果摘要

- V8.8G 只读快照通过。基线为 CLKEN=`0x21`、RST=`0`、MODULE=`0x02`、FIFO=`0x05`、DIV=`0x20/0x30`、MODE=`1`、MCTR=`0`、HOLD=`5`、STA/RAW=`0`；ADDR 读为 `0x133`，与本 OLED 的 7-bit 地址 `0x3C` 不同。
- V8.8H 按 ARM MasterInit 顺序将 DIV0/DIV1 设为 `0x3E7/0x3E7`，启用 TX/RX FIFO，设置 ADDR=`0x3C`，最后使能 I2C_EN。5 项写入均读回正确；MODULE=`0x0F`、FIFO 空、STA/RAW=`0`，Pad8/9 仍高。未发 TX 数据。
- V8.8I 的第一次启动因 Tcl 分隔符错误，在目标初始化前退出，目标 MMIO 写入 0。失败 marker 和日志保留。
- V8.8I 新阶段修正后完成身份/基线检查，只向 TX FIFO 写了一次控制字节 `0x00`。随后 40 轮状态读取均为 FIFO=`0x104`、STA=`0x1`、RAW=`0`，首字节没有消耗。脚本停止，没有写 `0xAE`，没有发 STOP、清标志、复位或重试。

## 真实结论

时钟门控、Pad8/9 AF3 开漏配置、慢速分频和控制器配置都可以按本轮顺序写入并读回。即使按照 ARM 参考的慢分频、7-bit 地址 `0x3C`、FIFO 和 I2C_EN 顺序，控制器仍停在首字节阶段。因此当前阻塞已从“时钟/引脚/寄存器配置”收窄到“事务启动与控制器推进/反馈”这一层；无法凭 `RAW=0` 判定 OLED ACK，也没有示波器波形证明物理 START/SCL。

当前控制器不是空闲态：FIFO 有一字节，WORK 位为 1。**停止所有进一步 I²C 写入；不要补写命令、STOP、清标志或软复位。** 后续需要先用新的独立阶段确认恢复方法（整板掉电重插可清状态，但本轮没有执行），再在安全隔离的测量接法下观察 Pad8/SCL、Pad9/SDA；若不做波形测量，需向原厂核实流片版 START/FIFO/反馈时序，不能继续猜寄存器值。

## 阶段与日志

| 阶段 | 动作/结果 | 原始日志 SHA256 |
|---|---|---|
| V8.8G `BBX_V88G_I2C_BASELINE_READ_01` | 只读，0 次目标写入；PASS_READ_ONLY_I2C_BASELINE | `1A611C1963E249DD6F90AA31771E332E19C5A2F2879F5061E04A31CF64C217C2` |
| V8.8H `BBX_V88H_I2C_CONTROLLER_READY_01` | 5 次目标写入；PASS_CONTROLLER_READY_NO_TRANSACTION | `CCAEB4B1109FF8E83DE694814095A9661A04F6A2248965466D43FF9804B0EFD5` |
| V8.8I-01 `BBX_V88I_OLED_DISPLAY_OFF_COMMAND_PROBE_01` | Tcl 解析失败、0 次目标写入；marker 保留 | `45A8B7A14F9BA2B282A7072BC2A7DD6AF8A2EADEED1F1C0ACE8E90DDB3BF4408` |
| V8.8I-02 `BBX_V88I_OLED_DISPLAY_OFF_COMMAND_PROBE_02` | 1 次 TX_FIFO=`0x00`；40 轮未推进，停止 | `441CDE09024F36F71149E5E33411DA9DEE8711BF553DB577B4310EF59802458D` |

运行目录：

- `runs/BBX_V88G_I2C_BASELINE_READ_01_20261105_204929_391954/`
- `runs/BBX_V88H_I2C_CONTROLLER_READY_01_20261105_205228_650336/`
- `runs/BBX_V88I_OLED_DISPLAY_OFF_COMMAND_PROBE_01_20261105_205706_944455/`
- `runs/BBX_V88I_OLED_DISPLAY_OFF_COMMAND_PROBE_02_20261105_205818_795804/`

所有 command/result/stdout/stderr/combined logs 和阶段 markers 均保留。V8.8I-02 OpenOCD 返回码为 0，Tcl 完成标记存在，但阶段结果为 `FAIL_OR_UNKNOWN`，不能将 OpenOCD 退出成功误判成 I²C 通过。最终 SBCS=`0x20040404`，DMSTATUS=`0x00430382`；无目标复位或重试。
