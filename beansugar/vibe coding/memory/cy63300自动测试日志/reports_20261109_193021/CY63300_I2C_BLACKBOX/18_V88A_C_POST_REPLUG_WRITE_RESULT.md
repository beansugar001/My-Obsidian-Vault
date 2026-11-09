# V8.8A–C：重插后基线与时钟门控判别结果

日期：2026-11-05（Asia/Shanghai）  
范围：重插后的只读确认；随后分别测试一次 `PERI_CLKEN=0x20` 与一次 `PERI_CLKEN=0x21`。三阶段均使用独立 marker；不写 I²C 控制器、FIFO、reset、Flash/NVR，不 resume，不重试。

## 实际结果

| 阶段 | 动作 | 结果 |
|---|---|---|
| V8.8A | 只读身份/CPU/SBA/时钟检查 | IDCODE 正确；CPU 从 running 被 halt 一次并确认 halted；DMSTATUS/SBCS 正常；CLKEN=0、RST=0。因 I²C 时钟关闭，按规则跳过 I²C 内部寄存器。目标 MMIO 写 0 次。 |
| V8.8B | 条件满足后仅写一次 `0x4002180C <- 0x20` | 写请求返回，SBCS 无 busy/error；写后两次独立读回仍为 `0`，RST仍为0。目标 MMIO 写请求 1 次。没有读取 I²C 内部寄存器。 |
| V8.8C | 新独立阶段，仅写一次 `0x4002180C <- 0x21`（GPIO+I²C clock） | 写请求返回，SBCS 无 busy/error；写后两次独立读回仍为 `0`，RST仍为0。目标 MMIO 写请求 1 次。没有读取 I²C 内部寄存器。 |

### V8.8A 关键读数

- DAPLink：`07000001006700343500000a4e57354aa5a5a5a597969908`
- 唯一 TAP / IDCODE：`riscv.cpu` / `0x1E200A6F`
- CPU：初始 `running`；脚本发送一次 `halt 2000`；随后 `halted`
- DMSTATUS=`0x00430382`；SBCS=`0x20040404`
- PERI_CLKEN=`0x00000000`；PERI_RST=`0x00000000`
- I²C 内部寄存器：跳过，因为 clock-off
- 原始 combined log SHA256：`B31A5E47ADE546E6A05DA0F42A5845B2E181F560144954BA6FB9DEA41398A4C6`

V8.8A 首次生成的 `result.json` 因复制脚本时结果前缀仍指向 `V87D_RESULT`，误写 `INCOMPLETE_OR_UNKNOWN`。原始日志完整保留，日志里有 `V88A_RESULT=BLOCKED_I2C_CLOCK_OFF TARGET_MMIO_WRITES=0`。已另存 `reconciled_result.json`，并修正后续 runner 的解析前缀；未重连硬件、未重跑阶段。

### V8.8B 关键读数

- 前置：IDCODE=`0x1E200A6F`、CPU halted、DMSTATUS=`0x00430382`、SBCS=`0x20040404`、CLKEN两次为0、RST=0。
- 只发出一次目标写请求：`0x4002180C <- 0x00000020`。SBDATA DMI 写请求返回；之后两次独立 SBA 读回均为0。写前后 SBCS均为`0x20040404`，没有错误位。
- 目标 MMIO 写请求计数：1。控制器、FIFO、分频、reset、Flash/NVR：0次写入。
- 原始 combined log SHA256：`519C6084A678850C6C9642E22D2793932B0226DDF3E3C6744A092EF7729AEB53`

### V8.8C 关键读数

- 前置：IDCODE=`0x1E200A6F`、CPU halted、DMSTATUS=`0x00430382`、SBCS=`0x20040404`、CLKEN两次为0、RST=0。
- 新阶段只发出一次目标写请求：`0x4002180C <- 0x00000021`。之后两次独立读回仍为0，RST=0；SBCS仍无 busy/error。
- 目标 MMIO 写请求计数：1。没有进入 I²C 内部寄存器快照。
- 原始 combined log SHA256：`2DBE64CFFAEC5DC9EE94621E04F6E6A6CCA512B3B4763FFE2641B519E92494B1`

## 与此前成功的 V7.8 对照

V7.8 在当天较早时段以相同 OpenOCD 二进制 SHA256 `EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27`、相同 100 kHz 配置 SHA256 `CB6064F0866A495C067C634FAB91C9A2084AE1805E171C6BCA5758F3A241A4A1`、相同探针序列号、IDCODE、DMSTATUS、SBCS、halt 状态，使用同一 V4.4 `SBADDRESS0→SBDATA0` 连续请求顺序，将 `PERI_CLKEN` 从0写为0x20并读回两次成功。

V8.8B 的目标地址、值、OpenOCD/配置、探针、CPU halted 状态、SBCS 和地址到数据的连续写序列与 V7.8 相同；结果却不可见。V8.8C 增加 GPIO clock bit0 后写0x21，读回仍为0。V7.8 的预检在 clock-off 时还额外读取过 MODULE_CTRL（读数0），该读数按手册不应作为 clock-off 状态的有效依据；V8.8B/C 没有此读取。除此之外，现有日志没有显示能够解释成功/失败差异的 SBA 命令顺序变化。

## 结论与证据边界

1. **重插后 JTAG、CPU halt、DMSTATUS 和 SBA 读取链路本轮可用。**
2. **当前会话里，SYSCTRL clock-gate 写入未对独立读回可见。** 这发生在任何 I²C 内部寄存器或 OLED 事务之前；ARM I²C 初始化、START/FIFO 顺序目前不是本轮失败的直接位置。
3. SBCS clean 和 DMI 写请求返回不证明 SYSCTRL AHB 写已经被目标接受/提交。两个不同门控值都读回0，仍不能区分 SBA 发起/互联提交问题、SYSCTRL 写接受条件，或硬件/连接状态变化。
4. 由于 V7.8 曾在同芯片/同探针用同一写序列成功，**不能断言芯片永久无法写，也不能把本轮失败归因于 I²C IP 损坏**。这是当前会话的写入可见性失败，与 V7.8 历史成功并存。
5. 本轮没有读取 I²C 寄存器。当前最后已知 PERI_CLKEN=0、PERI_RST=0；重插后 I²C FIFO 是否空闲仍未知。不得继续尝试 I²C 配置或发送 OLED 数据。

## 建议的下一步

- 暂停再次写 `PERI_CLKEN`。V8.8B 和 V8.8C 的独立阶段各已用完一次目标写预算；不复用 marker、不做同值重试。
- 先对照 V7.8 与 V8.8B/C 的完整 DMI 原始操作和运行环境，确认只有 preflight 中一个无效 clock-off I²C 寄存器读取差异，且没有隐藏 OpenOCD 客户端、探针序列或配置变化。
- 由于通用 SRAM SBA 写和 Program Buffer CPU store 以前都未得到可靠对照，后续不要将 `SBCS=clean` 当作目标提交证明。若要继续实物区分，需先取得供应商对该硅片 debug/SBA 写接受/完成信号或可用 CPU 执行路径的说明；否则新的写入只会重复出现“请求返回但目标读回不变”的歧义。
- I²C 初始化路线暂时停在“使能外设时钟之前”。只有重新建立可重复的 SYSCTRL 写入证据并完成只读 I²C reset-idle 快照后，才回到 ARM 分频、FIFO 和 OLED 帧测试。

## 原始记录位置

- V8.8A：`runs/BBX_V88A_POST_REPLUG_READONLY_01_20261105_202841_503499/`
- V8.8B：`runs/BBX_V88B_CLOCK_GATE_AND_IDLE_SNAPSHOT_01_20261105_203209_867216/`
- V8.8C：`runs/BBX_V88C_GPIO_I2C_CLOCK_AND_IDLE_SNAPSHOT_01_20261105_203451_054530/`
- 三阶段 marker 均保留在 `markers/`，均不得复用或删除。
