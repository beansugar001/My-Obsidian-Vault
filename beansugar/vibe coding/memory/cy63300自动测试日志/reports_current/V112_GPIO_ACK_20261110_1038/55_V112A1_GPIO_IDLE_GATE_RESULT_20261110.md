# V112A1 GPIO 空闲电平门禁结果

## 结果

新上电只读基线 `BBX_V112A0_READONLY_01` 通过：IDCODE=`0x1E200A6F`、DMSTATUS=`0x00430382`、SBCS=`0x20040404`、PERI_CLKEN=`0`、PERI_RST=`0`。本阶段一次 halt 成功。

V112A1 随后只开启 GPIO 外设时钟：`0x4002180C <- 0x00000001`，读回 `0x00000001`。I²C 时钟 bit5 保持 0，未访问 I²C 内部寄存器。GPIO 默认寄存器读回 ODR=`0`、DIR=`0`、OSOD=`0`、AFR1=`0`。

GPIOB IDR=`0x00000020`，B2/Pad8 和 B3/Pad9 均采样为低。命中 `BUS_NOT_IDLE_HIGH_BEFORE_CONFIG` 后按停止条件终止：没有配置开漏/输出，没有 START、地址、ACK 或 STOP 帧。收尾写 `GPIOB_DIR=0` 仍读回 0，只是保持输入高阻。最终 CLKEN=`1`，SBCS=`0x20040404`。目标 MMIO 写入计数为 2（GPIO 时钟开启 1 次、DIR=0 高阻收尾 1 次）。未复位、resume、写 I²C/FIFO、Flash/NVR 或重试。

## 与既往证据的关系

V90 已在不同上电状态下以 GPIO 方式完成 `0x3C` 和 `0x3D` 地址帧，均得到 NACK；当时 GPIOB PUPD=`0x300`，IDR 对应线位为高。本次重上电后 PUPD 默认 0，GPIO 输入位低。由此内部上拉/Pad 输入路径是重要差异，但本次读数本身不能证明外部 OLED 接口电压低，也不能证明 OLED 损坏。

## 下一步

单独读取并核实 GPIOB PUPD 后，若仍为 0，下一阶段仅设置 GPIOB B2/B3 的内部上拉字段（依据已有 V90 值 `0x300`），再读回 PUPD 和 IDR。此步骤不发总线帧、不打开 I²C 控制器。只有两条线被确认采样为高，才考虑在新的独立阶段重测一次 `0x3C` 地址 ACK。

## 原始证据

- 日志目录：`runs_local_v109/BBX_V112A1_GPIO_ACK_0X3C_01_20261110_103016_332275`
- Tcl SHA256：`84BC77501509E1B0C34093E1A5CCD4E9736FAB03F01CF02105E86DC46610D00D`
- Python 执行器 SHA256：`F2C3EE1D8AF3571AB506E5BB044CFEEDF7C7FDDB8C4736F7C5F1FCFD2A228263`
- OpenOCD 综合日志 SHA256：`D960843D085E0792F03301F6E1671A8C799886C31E295F2839D7034DA6824955`
- 结果：`FAIL_OR_UNKNOWN`（按电平门禁正常停止；ACK 未采样）
- 阶段 marker：`markers/BBX_V112A1_GPIO_ACK_0X3C_01.attempted.json`，保留且不可重跑。
