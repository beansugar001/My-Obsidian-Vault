# V90 GPIO 内部下拉特征测试结果

## 结论

这项检查不需要示波器或万用表：固件临时把 Pad8/SCL、Pad9/SDA 设为 GPIO 输入和内部弱下拉，再从 GPIO 输入寄存器读取电平。结果为两条线都跟随内部下拉变低。它说明测试时没有观察到足以压过内部弱下拉的外部上拉路径；因此优先怀疑 OLED 接口的上拉/供电路径或板级连通/引脚配置，而不是先归因于 I²C 控制器 FIFO。

这不能单独证明 OLED 坏、线断或电压异常。弱外部上拉、模块未供电、模块端上拉未接到这两根网、引脚复用/输入通路问题，都可能产生相同结果。此前 GPIO 地址探测对 0x3C 和 0x3D 均采到 NACK，也与“从机没有拉低 SDA”相符。

## 测试过程与结果

| 阶段 | 操作 | 结果 |
|---|---|---|
| `BBX_V90_GPIO_EXTERNAL_PULL_SIGNATURE_01` | 尝试进入弱下拉签名测试 | 脚本在 GPIOB_DIR 切换后因 Tcl 十六进制/十进制字符串白名单错误停止；仅发生 1 次 DIR 写。此阶段结果无效，原日志和 marker 保留。 |
| `BBX_V90_GPIO_EXTERNAL_PULL_RESTORE_01` | 把 GPIOB_DIR 恢复为 `0xC` | PASS。写前 DIR=`0`、PUPD=`0x300`、IDR mask=`0xC`; 写后 DIR=`0xC`、IDR=`0x2C`、SBCS=`0x20040404`。只写 1 次。 |
| `BBX_V90_GPIO_EXTERNAL_PULL_SIGNATURE_02` | 输入释放 → PUPD=`0x00C` → 采样 → PUPD=`0x300` → DIR=`0xC` | 完整通过并恢复。弱下拉采样 `IDR=0x20`、Pad8/9 mask=`0x0`；最终 `IDR=0x2C`、mask=`0xC`。SBCS=`0x20040404`。4 次目标 GPIO MMIO 写。 |

阶段 02 开始快照：`CLKEN=0x21`、`RST=0`、`MODULE=0x2`、`FIFO=0x5`、`STA=0`、`RAW=0`、`AFR0=0`、`AFR1=0`、`ODR=0xC`、`DIR=0xC`、`OSOD=0xC`、`PUPD=0x300`、`IDR=0x2C`。测试没有发送 I²C 地址或数据帧，没有改 I²C 控制器寄存器，没有复位、resume、Flash/NVR 操作。

## 阶段 02 日志

- 原始目录：`runs/BBX_V90_GPIO_EXTERNAL_PULL_SIGNATURE_02_20261107_125338_974821`
- 状态：`LINES_FOLLOW_WEAK_PULLDOWN`
- 综合日志 SHA256：`A4A878D0412D422ED8B72B4677C7C92EF54198F45780C15205D3BF0AE34D1F93`
- 恢复阶段目录：`runs/BBX_V90_GPIO_EXTERNAL_PULL_RESTORE_01_20261107_125239_439521`
- 恢复日志 SHA256：`BCB479D6EB03DCE086ED1E566D464B2F0A73D1144EA3C1D43F18C455BBAB6DF0`
- 离线回归：31/31 通过；实际阶段脚本也通过离线静态审计。

## 对“是不是配置问题”的判断

有可能，而且现有软件证据把优先级推向 Pad/总线上拉路径：GPIO 模式下本芯片能把 SCL/SDA 拉低并释放，释放时两线读高；弱下拉阶段两线都变低；恢复内部上拉后又读高。换句话说，芯片 GPIO 输入/输出控制有响应，但在弱下拉竞争下看不到足够强的外部高电平来源。I²C 地址采样时 SDA 保持高、OLED NACK，因而当前更像“从机没有在 ACK 槽拉低 SDA”，尚不能说硬件 I²C IP 损坏。

## 下一步

1. 先软件只读核验 GPIOB PUPD=`0x300`、DIR=`0xC`、AFR0/1=`0`、IDR mask=`0xC`，确认复位/重插后配置没有漂移。
2. 若仍不接示波器，下一项最有区分度的软件实验是由 GPIO 产生一次 START+地址帧，并在第 9 个时钟采 SDA；当前已有 0x3C/0x3D NACK 证据，因此应避免重复相同帧，优先确认模块端上拉/供电/Pad 路由配置是否有设计资料可核对。
3. 软件读回无法证明模块连接器处的模拟电压、边沿质量或 START 到达 OLED；若软件配置完全一致且仍 NACK，最终仍需在 OLED 连接器侧测量或用已知正常从机作对照。

本结论不宣称 OLED 损坏，也不宣称 OLED 已被芯片成功访问。
