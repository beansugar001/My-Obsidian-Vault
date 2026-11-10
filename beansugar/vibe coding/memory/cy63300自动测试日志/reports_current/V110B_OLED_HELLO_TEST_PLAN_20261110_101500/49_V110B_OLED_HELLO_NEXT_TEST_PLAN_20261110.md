# 下一步测试计划：从干净上电基线到 OLED 显示 Hello

日期：2026-11-10  
阶段：V110B 起；当前仅计划，尚未执行任何 V110B 目标写入。

## 当前基线

V110A 在重新插拔后确认：JTAG IDCODE=`0x1E200A6F`、DMSTATUS=`0x00430382`、SBCS=`0x20040404`；`PERI_CLKEN=0`、`PERI_RST=0` 各连续读三次一致。没有目标 MMIO 写入。由于 I²C 时钟关闭，本轮没有读取 I²C 内部寄存器。

因此上一轮 I²C 软复位位已通过重新上电回到 0；本轮还未重新开启 GPIO/I²C 时钟，也没有新的 FIFO 传输结果。

## 接线门

OLED 必须接在总线上，实际通信阶段才能观察到 ACK 并显示 Hello：

- GND → 目标板 GND
- VCC → 3.3V
- SCL → Pad8 / GPIOB2
- SDA → Pad9 / GPIOB3

如果 OLED 已接好且线未动，保持原状；若目前没接，先断开目标板供电再接，禁止带电插拔。接线确认后再给板子上电。

## 分阶段执行

| 阶段 | 操作 | 成功判据 | 失败停止条件 |
|---|---|---|---|
| V110B-0 只读门禁 | 新 marker；检查唯一 TAP/IDCODE、序列号、CPU halted、DMSTATUS、SBCS；CLKEN/RST 各读三次 | IDCODE 正确、SBA idle/error-free、RST=0；CLKEN=0 或已处于预期 `0x21` | 任一异常即停止，不写寄存器 |
| V110B-1 开时钟 | 若 CLKEN=0，单次 `0x4002180C <- 0x00000021`；若已 `0x21` 则跳过；新会话独立读回 | CLKEN=`0x21` 连续读回一致，RST=0 | 读回不符、busy/error、连接异常即停止，不重写 |
| V110B-2 Pad 配置 | GPIOB2/3 先置高释放值 `ODR=0xC`，配置开漏 `OSOD=0xC`、输出方向 `DIR=0xC`，AF_DG=`0x6C0`（AF3）；每次写后核对 | 相关字段吻合；`(GPIOB_IDR & 0xC)==0xC`，SCL/SDA 空闲高 | 任一回读不符或任一线低，停止，不进入 I²C 控制器写入 |
| V110B-3 控制器基线 | 时钟/复位稳定后只读控制器寄存器，确认当前 divider、MCTR、HOLD、MODE、MODULE_CTRL、FIFO/STATUS/RAW 状态 | 无活动事务；FIFO 空；复位释放；当前值与手册可解释 | WORK 非空、FIFO 非空、状态异常或值不明即停止并保留快照 |
| V110B-4 初始化 | 按核对后的 RISC‑V 寄存器位图和 ARM 驱动调用顺序配置 divider、MCTR、HOLD、7-bit 地址、FIFO；先保持 I²C_EN=0，再读回；最后才单次置 I²C_EN | 只读回允许的目标值；I²C_EN 置位，TX/RX FIFO 位正确，保留位按掩码解释 | 字段有差异即停；不调整其它位“碰运气” |
| V110B-5 单字节探测 | OLED 已接；确认地址来自模块资料/一次受控 ACK 探测；只向 TX FIFO 写一个 `0x00` 控制字节；只读观察 FIFO/STATUS/RAW | TX 数从 1 到 0，WORK 返回 idle，无 NACK；如可行，示波器看到 SCL/SDA、ACK、STOP | 超时/字节不消耗/NACK/总线低立即停止，不发第二个字节、不复位 |
| V110B-6 OLED Hello | 仅 V110B-5 通过后，依 STM32 `4-1oled` 初始化 OLED 控制器；发送最小字符数据 `Hello` | OLED 可见 Hello；记录命令与数据、最终寄存器/状态和照片 | 初始化任一事务异常立即停在该点，不重复自动发送 |

## 控制器初始化依据与限制

公司 ZIP 中 `I2C_MasterInit()` 的顺序是：开启 I²C 时钟；配置 `CLK_DIV0/1`、MCTR、HOLD；开 TX/RX FIFO；设置 Master 模式。它不设置 `I2C_EN`；`I2C_Cmd(ENABLE)` 单独使能控制器，之后设置地址并写 TX FIFO。驱动的 `I2C_WrByte()` 只判断 TX FIFO 未满并写入，不能用其返回当作发送成功。`SCL_L` 需显式切换到 GEN_STOP；另有 `GEN_STOP` 自动 STOP 例程。

ZIP 内 ARM 引脚映射、寄存器宏和注释存在版本矛盾，且没有已执行通过的记录。RISC‑V 手册中的 PERI_CLKEN/PERI_RST bit5、Pad8/9 AF3 映射优先；不照搬 ARM 的 bit2 reset 映射或 PB0/PB1 AF2。

## 特别判别点

V109F 已经使用 `MCTR=0x2`（按既有 RISC‑V 解释为自动 STOP 模式）、地址 `0x3C`、I²C_EN 和 FIFO 使能，并把一个 `0x00` 写进 TX FIFO；读到 `FIFO_STA=0x104`、`STATUS=1`、`RAW_INTR=0`，该字节没有消耗。Pad8/9 AF3 开漏释放时 IDR 为高。V110A 只证明重新上电清掉复位、时钟恢复默认关闭，不能证明 V109F 卡点已消失。

因此 V110B-5 只能发一个字节，并在失败时保留现场。必须记录完整 FIFO count、WORK、RAW interrupt、CLKEN/RST、SBCS；示波器若接线方便则同步观察波形，但不以“读回成功”替代实际 ACK/STOP 证据。

## 风险和停止规则

- 每个硬件阶段使用全新唯一 marker，预检、动作和验证分会话记录；所有原始日志与 SHA256 归档到 `D:\Obsidian\notes\笔记\beansugar\vibe coding\memory\cy63300自动测试日志`。
- 每阶段开始前检查 JTAG client 冲突，核对唯一 TAP、CPU 状态、DMSTATUS、SBCS。
- 不自动重试、恢复、软件复位、CPU resume、Flash/NVR 写入或断电重启。
- 失败后只读取可安全访问的状态并保存日志；不在 FIFO 卡住状态下再次写 FIFO。

## 下一步

先确认 OLED 是否已经接在 Pad8/Pad9。若已接，保持并进入 V110B-0；若未接，先在目标板断电时按上述四线连接，再重新上电，然后进入新的 V110B-0 只读门禁。

