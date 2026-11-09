# V104 GPIO 输入路径核对结果（2026-11-09）

## 依据

- 《CY63300 数字设计说明》GPIO 章节：GPIOB 基址 `0x40000100`，IDR 偏移 `0x50`，所以 GPIOB IDR=`0x40000150`；DIR 偏移 `0x04`，CS_TYPE `0x54`，OSOD `0x58`，PUPD `0x5C`，AFR1 `0x68`，AFR2 `0x6C`。
- 同一文档 IO 复用表（RISCV 版）：Pad8=GPIOB[2]，Pad9=GPIOB[3]；Pad8 的复用 0 是 GPIOB[2]，Pad9 的复用 0 是 GPIOB[3]。
- ARM GPIO 驱动 `GPIO_ReadBit()` 返回 `!!(GPIOx->IDR & Pin)`；GPIO 默认 `DIR=0` 是输入。
- 用户确认示波器探头连接到 Pad8/SCL，地夹接目标板 GND；示波器测到约 3.3 V。

## 实物快照

阶段 `BBX_V104C_GPIO_IDR_SNAPSHOT_HALT_01`，唯一 halt 请求一次，目标 MMIO 写入 0 次：

| 项目 | 读数 | 含义 |
|---|---:|---|
| IDCODE | `0x1E200A6F` | 目标 TAP 身份符合 |
| DMSTATUS | `0x00430382` | Hart halted |
| SBCS | `0x20040404` | SBA idle，无 busy/error 标记 |
| PERI_CLKEN | `0x00000001` | GPIO 时钟开；I²C 时钟 bit5 关闭 |
| PERI_RST | `0x00000000` | 复位寄存器读 0 |
| GPIOB ODR / DIR | `0 / 0` | PB2/Pad8 输入；输出锁存为低 |
| GPIOB CS_TYPE | `0` | 默认输入缓冲类型 |
| GPIOB OSOD / PUPD | `0 / 0` | 默认推挽/无内部上拉下拉 |
| GPIOB AFR1 / AFR2 | `0 / 0` | Pad8/9 对应字段均为默认值；按 RISC-V 复用表，AFR1=0 选 GPIOB[2]/[3] |
| GPIOB IDR，连续 3 次 | `0x20 / 0x20 / 0x20` | PB2=0、PB3=0；PB5=1 |

因此，在用户确认外部 Pad8 电压为 3.3 V 的同时，GPIOB 输入寄存器连续三次将 PB2/Pad8 采为低。手册和软件地址/位映射与采样结果一致；原因尚未确定，可能位于芯片 PAD 输入采样/复用路径，也可能有手册与流片实现差异。该矛盾不解释此前 I²C FIFO 字节未消耗，需作为另一条诊断线索。

## 阶段执行记录

- V104 首次阶段因 CPU=`running` 而停止，目标写 0 次。
- V104B 发送一次 `halt 2000` 后，因脚本错误地把 SBCS 控制位 `sbreadonaddr` 当成错误而停止，未读取 GPIO；目标写 0 次。
- V104C 修正 busy/error 掩码后完成，只读快照 PASS，目标 MMIO 写 0 次；日志 SHA256：`F80E31D2AF719FC5EDE1740849150F8C55199872A99DF5DC305318D5F7570604`。
- V103 收尾阶段曾将 `PERI_CLKEN` 写 0 一次，但读回仍是 1。V104C 再确认当前 `PERI_CLKEN=1`。没有继续尝试恢复。
- 本轮 I²C 时钟为关，因此没有读取 I²C 内部寄存器，没有发送 I²C 事务。

## 下一项区分测试

在当前示波器继续接 Pad8/SCL 和目标板 GND 的前提下，使用 GPIOB[2] 开漏输出做一次低电平保持后释放：ODR 锁存维持低，先置开漏，再把 DIR 设为输出拉低约 1 秒，随后将 DIR 恢复为输入并释放约 1 秒，最后恢复原 OSOD/DIR。禁止主动驱高；每次写后独立读回；失败即停。示波器应看到“低约 1 秒、随后回到高电平”。

- 若示波器见到低后回高，但 IDR 仍 PB2=0：GPIO 输出到 Pad 路径通、IDR 输入采样/映射异常成为强候选。
- 若示波器无低电平变化但 GPIO 寄存器读回改变：输出使能/复用到 Pad 的路径或 Pad 绑定实现异常成为候选。
- 若恢复阶段读回失败：不重试，不做其他 GPIO/I²C 写入，保留现场。

此测试不产生 I²C START/FIFO 数据，不改 Pad9，不写复位、Flash 或 NVR。

## V105 之后的复核补充

ARM `SECURITY/SRC/com.c` 对 GPIOB5 软件片选使用 `GPIO_AlternateFunction(GPIOB, GPIO_Pin_5, 0, GPIO_Digital)`，随后调用 `GPIO_Init` 与 `GPIO_SetBits`；GPIO driver 的 `GPIO_AlternateFunction()` 将数字 AFR1 对应字段写成 `Func`，`GPIO_Init_b()` 则直接设置 DIR。它支持 AF0 作为软件 GPIO 的参考用法。V105 Pad8 已是 AFR1=0，且 OSOD/DIR 改变可读回，但用户没有看到 Pad8 拉低。因此目前没有发现一个可从 ARM 驱动直接补上的、遗漏的 GPIO 软件使能步骤；仍需考虑流片 Pad mux/绑定与文档/ARM SDK 版本之间的差异。
