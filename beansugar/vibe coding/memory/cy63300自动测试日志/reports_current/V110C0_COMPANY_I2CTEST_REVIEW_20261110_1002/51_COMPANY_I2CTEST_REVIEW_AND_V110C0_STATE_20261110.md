# 公司 `I2CTest()` 对照及当前芯片状态

日期：2026-11-10

## 本轮执行

用户已接好 OLED，并要求参考公司 `CY63300.c::I2CTest()` 流程。本轮先对芯片进行了新的只读状态快照；没有写目标 MMIO、复位、恢复或发送 FIFO 数据。

阶段：`BBX_V110C0_READONLY_01`  
探针：`07000001006700343500000a4e57354aa5a5a5a597969908`  
IDCODE：`0x1E200A6F`  
DMSTATUS：`0x00430382`；CPU 初始 running，本轮发出一次 halt 请求后确认 halted。  
SBCS：`0x20040404`，idle，无 sticky error。  
PERI_CLKEN：`0x00000021`，三次一致。  
PERI_RST：`0x00000000`，三次一致。  
MODULE_CTRL：`0x0000000F`，三次一致。  
FIFO_STA：`0x00000104`，三次一致，TX FIFO 仍有 1 字。  
I2C_STATUS：`0x00000001`，三次一致，I2CM_WORK 仍为 1。  
RAW_INTR：`0x00000000`，三次一致。  
本阶段目标 MMIO 写次数：0。

结果：JTAG 与寄存器只读链路正常；控制器仍处于 V110B5 的未完成事务状态。当前不应在该现场追加公司函数中的四次 TX FIFO 写入。

原始完整日志：`runs_local_v109/BBX_V110C0_READONLY_01_20261110_100222_362889/openocd.combined.log`  
SHA256：`F5BC0F15210239D7A82636DEBAA2D9E8C9DB23C1FEF2C1C23343388FEA816FBF`

## 公司函数逐项复核

来源：`D:\project\RISCV-63300\恢复jtag后\CY63300_flash.zip` 内 `DEBUG/CY63300.c`，函数 `I2CTest()`，源码行 522–556。ZIP SHA256：`F4AE88059A86A4FF473B653C588527A8ABE316F95E6F681A353CF2D848106D9C`；ZIP 内源文件 SHA256：`DC6A636102CF9C0FE7E912B8A31F5C20C37268342E226464ADFCD2467494180B`。

| 顺序 | 公司 `I2CTest()` 动作 | 结果与注意点 |
|---|---|---|
| 1 | 开 GPIO PCLK；把 GPIOB pin0/1 配成推挽输出、强驱动、快速，AF2 | 与当前 RISC-V 实物使用的 Pad8/9 = PB2/PB3、AF3、开漏不是同一组管脚/电气配置，不能照抄。 |
| 2 | H=`0x10`、L=`0x24`、HOLD=`5`、GCALL/SBYTE/HS=0、`STOP_MODE=SCL_L`、7-bit | 驱动把 H/L 各减 1 后写 DIV0=`0x0F`、DIV1=`0x23`；MCTR 的 STOP 位为 0，即 FIFO 空时保持 SCL 低，等待软件产生 STOP。 |
| 3 | `I2C_MasterInit()` 开 I²C PCLK，按顺序写 DIV0、DIV1、MCTR、HOLD、MD_CTR 的 TX/RX FIFO 位、MODE=Master | 这与通用 I²C 寄存器块顺序可作为流程参考；函数没有复位、延时、逐项读回或 ready 轮询。 |
| 4 | `I2C_Cmd(ENABLE)`，设置地址 `0x55` | 地址为 7-bit；`0x55` 不是当前 OLED 地址，不能直接拿来测试 OLED。 |
| 5 | 连续向 FIFO 写 `0x11, 0x22, 0x33, 0x44` | `I2C_WrByte()` 只等 FIFO 不满，然后写 FIFO；它不等待 ACK、FIFO 排空或 WORK 清零。 |
| 6 | 立即关闭 I²C PCLK | 函数没有显式 `I2C_GenerateStop()`，也没有等传输结束；在 SCL_L 模式下 FIFO 空时预期保持 SCL 低。关闭时钟不是成功判据，可能中断正在进行的传输。 |

这段 `I2CTest()` 是“排入数据”的短测试代码，不是带成功判定的完整总线验收。它没有报告 ACK/STOP/完成状态，不能证明曾在实物上成功，也不能作为 OLED 驱动序列原样复用。

## ARM 与 RISC-V 的共性和差异边界

- I²C 控制器寄存器窗口在 ARM 驱动和 RISC-V 设计说明中对应 `0x40002800` 一带；控制、FIFO、分频、MCTR、地址等偏移与字段语义可作为共享 IP 的对照基础。
- SYSCTRL 时钟宏不能笼统地认为所有 ARM 文件完全一致：公司 `common_chip` 驱动 `I2C_PCLK` 使用 bit5，和 RISC-V 设计说明 `PERI_CLKEN[5]` 相符；同一批设备头文件仍有 bit2/bit5 的冲突定义。RISC-V 实物应按 RISC-V 手册和本轮实测读值。
- GPIO/PADMUX 是 SoC/封装映射，不因 I²C 寄存器相同而自动相同。公司函数选 PB0/PB1 AF2 推挽；当前 RISC-V 板根据 PADMUX/载板映射选 PB2/PB3 AF3 开漏。
- 公司函数采用手动 STOP 模式 `SCL_L`，当前 V110B 配置 MCTR=`0x2` 为自动 STOP 模式；这是可实测的流程差别，但 V110C0 的只读数据表明当前事务尚未从 FIFO 消耗，不能仅凭该差异断言根因。

## 决策与下一步

1. 当前状态仍为 `MODULE_CTRL=0x0F / FIFO_STA=0x104 / STATUS=1 / RAW_INTR=0`。不往现有 FIFO 追加数据，不尝试软件复位或关时钟清队列。
2. 需要先用**完整断电再上电**清除本次未完成状态。建议保持 OLED 四根线连接不动，关闭目标板供电并确保 DAPLink 不从 VTref/信号脚反向供电，等待数秒后再给目标板上电并重新连接 DAPLink；完成后从新的只读阶段开始。不要带电拔插 OLED。
3. 干净基线确认后，采用公司的“开 GPIO/I²C 时钟 → 分频 → MCTR/HOLD → FIFO → Master → enable → address → enqueue”顺序，但保留 RISC-V 的 Pad8/9 AF3 开漏配置；选 OLED 自身的 7-bit 地址，不用测试代码地址 `0x55`。
4. 修正公司短函数缺少的完成处理：一次只送一个经定义的 OLED 控制字节；轮询 TX count、WORK、RAW interrupt，并在字节确实消费后依 RISC-V 文档确认的方式请求 STOP；任何超时立即停，禁止再添 FIFO 数据。成功看到一笔完整事务后才运行 OLED 初始化及 `Hello`。

## 文件哈希

- 公司 ZIP：`F4AE88059A86A4FF473B653C588527A8ABE316F95E6F681A353CF2D848106D9C`
- ZIP 内 `DEBUG/CY63300.c`：`DC6A636102CF9C0FE7E912B8A31F5C20C37268342E226464ADFCD2467494180B`
- ARM I²C driver `cj32l01xx_i2c.c`：`0CB18540CFD2009A65137F86A2C06F94A26B5BE759287F8A91345223A086C379`
- ARM I²C header `cj32l01xx_i2c.h`：`CE1C031545D7B5F3FCEFE7E996E065B488D51D8FF21FF0E15289BC478E644EF7`
