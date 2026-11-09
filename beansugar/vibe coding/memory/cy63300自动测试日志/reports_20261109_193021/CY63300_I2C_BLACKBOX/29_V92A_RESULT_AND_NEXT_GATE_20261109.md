# V92A 实物只读快照结果与下一门槛

日期：2026-11-09（Asia/Shanghai）
阶段：`BBX_V92A_POST_REPLUG_FIFO_BASELINE_01`

## 结果

- OpenOCD 100 kHz，DAPLink 序列号核对通过：`07000001006700343500000a4e57354aa5a5a5a597969908`。
- JTAG TAP 唯一：`riscv.cpu`；IDCODE=`0x1E200A6F`。
- `misa=0x4C80680A`。
- CPU 初始为 running；发送一次 `halt 2000` 后确认为 halted。
- DMSTATUS=`0x00430382`；SBCS=`0x20040404`，busy/error 位正常。
- PERI_CLKEN 连续三次：`0x00000000`，一致。
- PERI_RST 连续三次：`0x00000000`，一致。
- 状态：`BLOCKED_I2C_CLOCK_OFF`。依据门槛，时钟关闭时没有读取任何 I²C 内部寄存器，因此 FIFO/WORK 当前状态仍未知。
- 目标 MMIO 写入：0；reset/resume/Flash/NVR：0；自动重试：0。
- **当前调试结束状态：CPU halted。** 本阶段没有 resume。

## 原始证据

运行目录：`runs/BBX_V92A_POST_REPLUG_FIFO_BASELINE_01_20261109_141954_980745/`

- `command.json` 记录实际 argv、工作目录、启动时间、互斥进程/端口快照及脚本/配置/OpenOCD SHA256。
- `openocd.combined.log` SHA256：`0D0AA64A8AA48A03582745960970EA4EB8D9F0C665E407C0314988AD33582151`
- `openocd.stderr.log` SHA256：`EBF977F59216E42B91E30F487FAF7925872053FB4D92A7C9073EFBB438D96C62`
- `openocd.stdout.log` 为空（SHA256 为标准空文件哈希）。
- `result.json`：OpenOCD 返回码 0、完成标记存在、阶段结果仍为 CLOCK_OFF 阻断；不能将 OpenOCD 成功退出解释成 I²C 成功。
- 阶段 marker 已创建并保留；不得复用或删除。

## 下一步门槛

当前计划不能进入 RAM 邮箱或 FIFO 探测，因为 PERI_CLKEN bit5 未开，I²C 内部状态也尚未读取。下一阶段需要先单独评估并准备一次受控的 SYSCTRL 时钟门控写入：目标寄存器 `PERI_CLKEN (0x4002180C)`，保留其他位、只置 bit5；写入前再次核对原值与复位状态，写后用独立只读事务验证，再读取 I²C idle/FIFO 状态。该写入不属于 V92A 只读阶段，本报告没有执行它，也不把 V92A marker 当作该阶段授权。

只有时钟开启后确认 FIFO 为空、WORK/DATA 清零、RAW 状态可解释，才继续离线审计安全 RAM 执行路径，再准备目标 CPU 连续采样的单次事务。
