# V121 STOP 探测结果与 V33 仿真/实物差异

日期：2026-11-10（Asia/Shanghai）

## 结论

这次新的 STOP 探测**没有写 MCTR.STOP**。脚本在实物检查到 `PERI_RST[5]=1` 后停止，目标写入 0 次。当前状态不满足用 STOP 验证“是否能传送卡在 FIFO 的字节”的条件：I²C 仍处于复位断言，FIFO 读数为 0，`WORK=0`。在这种状态写 STOP 得不到关于 FIFO 发送行为的有效结论。

前一轮 `BBX_OLED_CMD_AE_ACK_PROBE_20261110_01` 已在 `TX_NUM=1、WORK=1、DATA=0` 时尝试过一次 STOP；它没有清空 FIFO，也没有使 WORK 结束。因此现有实物证据不支持“写 STOP 会把未发送 FIFO 字节强制推出去”。按数字设计说明 §4.19.9，STOP 的语义是等 TX FIFO 空后结束传输并产生 STOP；STOP 不是 FIFO 清除命令。不能为了再次验证而在复位状态下写 MCTR。

## V121E 最新实物结果

阶段：`BBX_I2C_STOP_STALLED_FIFO_PROBE_20261110_05`

| 检查项 | 实测 |
|---|---|
| TAP / IDCODE | `riscv.cpu` / `0x1E200A6F` |
| DAPLink | 序列号 `07000001006700343500000a4e57354aa5a5a5a597969908` |
| CPU | 初始 running；发送一次 `halt 2000` 后继续检查 |
| DMSTATUS / SBCS | `0x00430382` / `0x20040404` |
| PERI_CLKEN | `0x00000021` |
| PERI_RST | `0x00000020`，I²C 复位仍断言 |
| MODULE_CTRL / FIFO_STA | `0x0` / `0x0` |
| I2C_STA / RAW_INTR / MCTR | 均为 `0x0` |
| STOP 写入 | **0 次**，按门禁跳过 |
| 阶段状态 | `STOP_SKIPPED_RESET_ASSERTED_OR_CLOCK_OFF` |

日志目录：`runs_local_i2c_next/BBX_I2C_STOP_STALLED_FIFO_PROBE_20261110_05_20261110_184107_659682`

- combined SHA256：`0BB8AA55F354CA132352B59102E923265DBC96DC6CDF62FF7C9DB8B7CE285EEB`
- stderr SHA256：`D918099BE02C9D42F966336E24D57F0ECA61098572D407334AB16DB54C60450F`
- marker：`markers/BBX_I2C_STOP_STALLED_FIFO_PROBE_20261110_05.attempted.json`，保留。

此前 STOP 实际尝试与 V120 复位结果详见 `57_V120_ARM_SINGLE_BYTE_RECOVERY_RESULT_20261110.md`。V120 写入复位断言 `0x20` 后读到 `0x20`，写释放值 `0x00` 后仍读到 `0x20`；没有发送额外 FIFO 字节。V121 的前几个入口只在脚本授权变量/启动门禁阶段失败，没有访问目标；后续 V121E 使用新阶段 marker 成功完成上述只读门禁。

## 仿真里的流程是什么

V33 不是 CY63300 流片 I²C IP 的 RTL 仿真，而是**手写的行为模型**。源码 `cy63300_v33_dmi_i2c/rtl/i2c_behavioral_mmio.v` 文件头明确标为 `behavioral I2C mock -- NOT CY63300 I2C RTL`，并注明“两个 TX_FIFO 字节写入（address+W，再 payload）启动传输”的 test dialect。

其测试过程是：

1. Testbench 通过仿真的 DMI/SBA/RIB 访问寄存器模型。
2. 先设置模型时钟门控、CLK_DIV0/1、主机模式、STOP、MODULE_CTRL。
3. 向 `TX_FIFO` 连续写入 `0x78`（模型约定的 0x3C+W 地址字节），再写入 `0xA5`（一个 payload）。
4. 行为模型检测到 `fifo_count==2` 后，**模型自身把 FIFO 计数清零并进入 START 状态**，再按自己定义的状态机依次模拟地址、ACK、数据、ACK、STOP。
5. Testbench 内的 BFM（总线功能模型）监视 SDA/SCL；它会在看到地址字节 `0x78` 时主动拉低 SDA 产生 ACK，再对数据字节 ACK，并统计 START/STOP/负载。
6. 仿真通过条件是这些计数器和预期值符合测试代码。它证明模型和 testbench 互相匹配。

模型还使用 `tri1` 理想上拉，并用模型自定的分频微步延时。源码明确指出其分频公式不是 CY63300 实际公式。BFM 也明确说它不是 OLED 模型，只是“7-bit 地址 + 一个数据字节”的 ACK 设备。

## 为什么仿真流程不能直接证明实物可用

- **被测对象不同：**仿真控制器是人为编写的 mock，不含实际流片 I²C IP 的状态机、FIFO 握手和寄存器副作用。
- **协议由模型预设：**仿真假设“两次 TX_FIFO 写入就启动”，而数字设计说明对地址寄存器的描述与 ARM API 命名/流程存在歧义；实物可能要求不同的地址装载、START/STOP、FIFO 触发或时序顺序。
- **从机 ACK 是 testbench 生成的：**仿真中 BFM 会按 `0x78` 主动拉低 SDA；实物没有这个 BFM，必须由 OLED 在实际总线上 ACK。寄存器写成功不等于已经出现 START 或收到 ACK。
- **实物多了未被模型覆盖的层：**芯片时钟/复位、APB 桥、PADMUX、开漏输出、上拉电阻、封装和载板连线、SDA/SCL 电气波形、OLED 电源与实际地址。
- **当前实物现象相反于 mock 的自动消耗行为：**OLED 命令探测里，一个 TX FIFO 字节留下 `TX_NUM=1`、`WORK=1`、`DATA=0`、`RAW_INTR=0`；没有已确认的 START/ACK，也没有 FIFO 消耗。这说明问题在真实发送开始/握手链路上，尚未到 OLED 命令解析或显示内容阶段。

因此，V33 仿真可用于验证 DMI/SBA/RIB 模型和一个假设的 I²C 事务脚本是否按模型工作；**不能据其 PASS 声称真实芯片的 FIFO 会按同样顺序启动、OLED 会 ACK 或 Hello 可显示。**

## 当前判断与下一步

1. 不在当前状态写 STOP：`PERI_RST=0x20`，模块寄存器读值为复位态。
2. 由用户重新断电上电/重新插拔后，开一个全新只读阶段确认 `PERI_RST=0`、`PERI_CLKEN`、MODULE_CTRL、FIFO、WORK、错误状态和 Pad8/9 空闲电平；不能复用旧 marker。
3. 根据已实测 STOP 不会清理卡住的 TX FIFO，不再把 STOP 当作 FIFO 强制排空手段。
4. 若上电后状态空闲，下一项最有信息量的事务应严格照 ARM 的 API 语义：先配置目标从机地址，再按其 Master 发送路径写一个数据字节，短时轮询 DATA/TX_NUM/错误位；只有满足 ARM 代码的发送里程碑才请求 STOP。任一状态卡住就只采样现场并停，不追加 FIFO 字节、不自动复位/重试。
5. 观察到有意义的引脚波形仍需示波器/逻辑分析仪。单纯 GPIO IDR 或寄存器读回不能证明连接器端波形。

## 证据边界

- **实物证据：**V121E 读数及前轮一次 STOP 尝试没有排空 FIFO；V120 软复位释放值没有回到 0。
- **文档/ARM 证据：**STOP 语义及 ARM 单字节发送的轮询顺序来自数字设计说明和 ARM 驱动，不能独自证明 RISC-V 实物完全采用相同实现。
- **行为模型证据：**V33 mock/BFM 描述其假设流程，不是流片 RTL，也不能用于断言 ASIC 内部原因。
- **尚未证明：**当前具体卡在 START 触发、实际 IP FIFO 读取握手、时钟/复位传播、寄存器译码还是 Pad 电气输出；这些需要上电后的新只读基线、受控单字节试验及实际 SDA/SCL 波形来区分。
