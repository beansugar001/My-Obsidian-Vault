# V138 PAD复用原表审查与PAD1单字段实验

## 原始资料视觉核对
使用PDF技能只读渲染《数字设计文档》PDF第145页(ARM表)、第146页(RISC-V表)，图片padmux_arm_p145.png、padmux_riscv_p146.png保留。文本提取会吞空格列，不能用于判断表列。
- RISC-V PAD0：AF0 JTAG_TDI，AF1 I2C_SCL输入，AF5频率检测输入，AF6 GPIOA0。
- PAD1：AF0表格空白（行为未明确），AF1 I2C_SDA，AF5频率检测输入，AF6 GPIOA1。
- Pad8/9：AF3分别I2C_SCL/SDA；Pad8的SCL为io。
- 原表注释：同一个IP同时复用到多个PAD时，低编号PAD优先。
ARM表PA0/1的AF5也为频率检测，AF6为GPIO；ARM例程对PA0/1写AF5的真实作用不能仅按其注释解释为GPIO。GPIO_AlternateFunction函数按3*i直接写Func，无+1偏移。
纠正：此前网页报告称PAD1默认I2C以及本轮早期口头“默认包含SDA”，均缺少原表支持；表中SDA在AF1。AF0留空也不能保证其电气行为已知。V39报告称PA0/1无关，不能忽略原表的低PAD优先规则；是否真的冲突需实际读值与厂商输入门控信息。

## 只读快照
GPIOA_AFR1=0、GPIOB_AFR1=0x6C0、GPIOC_AFR1=0；各组AFR2=0。按表字段解码没有另一个明确选中的I2C候选；PAD1 AF0为空白。读到CLKEN=0x21、RST=0、DRIVE=0xC、FIFO=0x104、STA=1、RAW=0。
脚本另只读0x40021808，使用历史标签JTAG_CFG_READONLY且值为0；该地址在现有设计文档中有OSC_CR定义，RISC-V特化映射未核实，不能从标签推论JTAG_CFG=0或需要改写。未写该地址，不从其作诊断结论。

## 单变量实测
在V136/V137已卡事务上，确认GPIOA_DIR=0、GPIOA_AFR1=0以及I2C现场一致；只写GPIOA_AFR1 0x40000068 <-0x30（PAD1字段[5:3]=6，PAD0字段[2:0]仍0，PA3等字段不变）。利用写前读取不同地址策略，读回0x30成功，调试DMI状态在会话内仍可读取。未改变GPIOA DIR/ODR/PUPD、未写PAD0为AF5、未改JTAG脚的AF字段。
随后10次读FIFO=0x104、STA=1、RAW=0，无变化。结果FIFO_STILL_QUEUED_AFTER_PAD1_AF6。目标MMIO写1次，无FIFO/STOP/软件复位/Flash/NVR/SRAM写，无resume，halt一次。最后确认GPIOA_AFR1=0x30；断开后实际状态未持续观察。

## 结论与限度
不支持“已卡住后把PAD1切出空白默认功能立即恢复”的方案。不能排除必须在START前配置PAD1、其他硬件复用覆盖、实际输入优先级或表/芯片版本差异。仅寄存器AF读回不证明真实Pad输入路线，当前FIFO仍未消耗。不要不加区分修改PAD0（JTAG TDI），避免调试失联。

## 清单及后续
已完成：ARM/RISC-V原表视觉核对；所有组数字/模拟AF快照；PAD1单字段AF6读回与卡住事务观测。
未完成：发送前设PAD1=AF6的独立上电对照、真实外部波形和地址/ACK、CPU store与SBA差分、流片输入mux/FSM信息、OLED显示。
下一步应准备独立新上电对照，区分“运行中补配置”和“发送前配置”；不能把V137高驱动和V138PAD1同时改变后的成功/失败归结某一单项。也可在不写目标的前提下审计输入mux优先选择与halt时钟域，但参考RTL没有真实I2C IP，不能模拟替代实际门控。

只读日志runs_local_i2c_next/BBX_V138_PADMUX_READONLY_20261110_01_20261110_205056_604860，combined SHA256 2416D5CF54B16048973D6B3599A29916086D8DE8E6DB63714A07B2A9CC72CA97。
单写日志runs_local_v109/BBX_V138_PAD1_ONLY_AF6_20261110_01_20261110_205234_789552，combined SHA256 53F9CEF0DAC6ADAEC187B6B45AA1D84FA9DF89DDAB772529568162CD477EAA3F。
脚本I2C_NEXT_PHASE_20261110_01/v138_mux_readonly.tcl与03_experiments/v138_pad1_only_af6.tcl；marker和所有历史日志保留。
