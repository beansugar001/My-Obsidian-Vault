# 公司 `CY63300_flash.zip` ARM I²C 资料审阅与 V110A 上电后检查

日期：2026-11-10（Asia/Shanghai）  
ZIP：`D:\project\RISCV-63300\恢复jtag后\CY63300_flash.zip`  
ZIP SHA256：`F4AE88059A86A4FF473B653C588527A8ABE316F95E6F681A353CF2D848106D9C`

## V110A 实物只读快照

- DAPLink 序列号匹配：`07000001006700343500000a4e57354aa5a5a5a597969908`
- TAP/IDCODE：`riscv.cpu / 0x1E200A6F`
- hart 最终 halted；DMSTATUS=`0x00430382`；SBCS 最终=`0x20040404`
- PERI_CLKEN 连续三次稳定为 `0x00000000`
- PERI_RST 连续三次稳定为 `0x00000000`
- 因 I²C 时钟关闭，未读 I²C 内部寄存器；目标 MMIO 写入 0 次。阶段结果 `PASS_RESET_CLEAR_CLOCK_OFF`。
- 合并日志 SHA256：`08B758B2A9C392060C82472B1C431541143AD1E66C6E0BA404F4EB9C78C8DBB7`

解释：重新上电确实清除了 V109G 后保持的 `PERI_RST[5]`。当前回到 I²C 复位释放、外设时钟关闭的干净基线；尚未证明控制器发送恢复。

## ZIP 内的关键文件和流程

### 1. 驱动初始化

`DRIVER_LIB/src/cj32l01xx_i2c.c:212-231` 的 `I2C_MasterInit()`：

1. 调用 `PeriCLK_Cmd(I2C_PCLK, ENABLE)` 开 I²C 时钟。
2. 校验 General Call 与 10-bit 模式组合。
3. 写 `CLK_DIV0 = CLK_Div_H - 1`、`CLK_DIV1 = CLK_Div_L - 1`。
4. 配置 MCTR、HOLD。
5. 使能 TX/RX FIFO。
6. 选择 Master 模式。
7. **此函数没有置 `I2C_EN`**；`I2C_Cmd(ENABLE)` 才会置使能位（`:284-290`）。

`I2C_SetAddr()` 后，`I2C_WrByte()` 仅等待 TX FIFO 未满，然后把字节写入 FIFO（`:324-349`）。代码没有独立 START 寄存器写。现有 ARM 例程的编程模型是：先设地址，再写 FIFO，由控制器按其硬件协议启动；RISC‑V 流片是否同一实现，仍需实测/设计方确认。

`STOP_MODE` 有两种路径：`SCL_L` 表示 TX FIFO 空时保持 SCL 低；`GEN_STOP` 表示 FIFO 空时自动发 STOP（头文件 `cj32l01xx_i2c.h:46-50`）。使用 `SCL_L` 时 `I2C_GenerateStop()` 修改 MCTR 的 STOP 位（驱动 `:421-434`）。该函数中等待 STOP 中断和清中断的代码被注释，故“调用函数”本身不等于已确认 STOP 完成。

### 2. 测试例程的差异

- `DEBUG/CY63300.c:522-556` 的 `I2CTest()`：PB0/PB1 设置为推挽输出、AF2，7-bit，`STOP_MODE=SCL_L`；开启控制器后写地址 `0x55` 和四字节 `11 22 33 44`，随后立即关闭 I²C 时钟。没有显式 STOP，也没有等待 FIFO 清空、WORK 清零或 STOP 中断。**不适合作为 OLED 参考流程，也不能证明测试成功。**
- `DEBUG/CY6V100.c:730-776` 的 `I2CTestCase0()`：PB0/PB1 开漏、AF2；配置 7-bit、`SCL_L`，写四字节后发 RESTART/READ 控制字，调用 `I2C_GenerateStop()`，等待 RX FIFO 至少 4 字节再读取。它是 combined write/read 例程，并非单纯 OLED 写流程。
- `CY6V100.c:778-868` 的变体改变 START byte、自动 STOP、地址模式等；`CY6V100.c:870-924` 是 SDA 复用故障注入/读流程；`:937-977` 是从机流程；`:979-1016` 有地址错误测试；`:1018-1050` 是高速模式；`:1052-1088` 是另一个 7-bit 自动 STOP 变体。
- `I2C_Master_FS_Routine()`（驱动 `:27-78`）设置 GPIOA0/1 开漏、AF2，分频 0x10/0x24、HOLD=5、SCL_L，但设 `ADDR_MODE=ADDR_10bits` 后却注释 `I2C_SetAddr(0x354)` 为“7bit device_addr”；这种模式/注释不一致不能照搬。

### 3. 重要限制：源码有例程不等于例程已跑通

- ZIP 的 `USER/main.c:5-19` 只配置 SysTick/EFC，随后无限循环。
- `DEBUG/CY6V100.c:1658` 对 `I2CTestCase0()` 的调用被注释。
- ZIP 中 `I2CTest()` 只找到定义及头文件声明，没有实际调用点。
- ZIP 没有提供这几段 I²C 测试在目标芯片上通过的日志、波形或 OLED 结果。

所以这份资料可以用来重建软件顺序和设计测试分支，但不能称为已验证成功的 RISC‑V OLED 流程。

## ARM 与 RISC‑V 定义冲突

同一个 ZIP 内部也有不一致：

| 来源 | I²C 时钟位 | I²C 软复位位 |
|---|---:|---:|
| ZIP `DRIVER_LIB/inc/cj32l01xx_rcc.h` | bit5 (`I2C_PCLK=1<<5`) | bit2 (`I2C_Soft_Rst=1<<2`) |
| ZIP `DEVICE/cj32l01xx.h` | bit2；bit5 标成 SINKC | bit2；bit5 标成 SINKC |
| RISC‑V 数字设计说明 | bit5 | bit5 |

RISC‑V 的 CLK/RESET 位号应继续以本版数字设计说明为依据。V110A 证实重上电后 RISC‑V PERI_RST=`0`，但当前时钟也回到 `0`。不能因为 ARM `rcc.h` 中存在某个 enum 就把位号写进真实芯片。

## 与本次 OLED 测试的映射

- 旧例程 GPIOB0/B1、AF2 与本 RISC‑V 板的 Pad8/Pad9 GPIOB2/B3、AF3 不同；保持当前已核实的 Pad8=SCL、Pad9=SDA 映射。
- I²C 总线要用开漏并释放高电平；应参考 `CY6V100.c` 的开漏测试写法，而不是 `CY63300.c:I2CTest()` 的推挽配置。
- OLED 需要的是 7-bit 地址（常见 0x3C/0x3D，须按模块确认）以及控制字/初始化命令；ARM 测试用的 `0x55` 和 `11 22 33 44` 是自环/从机或普通通信测试数据，不是 SSD1306 OLED 初始化数据。
- 下阶段顺序应为：确认 OLED 已接好 → 只读确认 CLKEN/RST → 单独开启 GPIO/I²C 时钟 → 配置并读回 Pad8/9 开漏 AF3 → 使用确认过的 7-bit 地址及较慢分频 → 初始化 FIFO/模式/MCTR/HOLD → 使能 I²C → 单次发送一个 OLED 控制字节并读 FIFO/STATUS/RAW_INTR。记录 FIFO 消耗、WORK、NACK/STOP 和 SDA/SCL 波形/ACK；出现 FIFO 再次卡住立即停止，不追加写。

## OLED 连接建议

若 OLED 已连接且接线未动，保持连接即可。若 OLED 当前断开，先让目标板断电再接线，避免通电时碰线：OLED `GND→板 GND`、`VCC→3.3V`、`SCL→Pad8/SCL`、`SDA→Pad9/SDA`；确认模块供电标注后再上电。若没有断开，不必为本只读基线拆装 OLED。

## 下一步门槛

V110A 的只读基线通过。继续实物时先确认 OLED 接线状态；然后准备一个新阶段，仅开启所需时钟并独立核对。不要重用旧 marker；不要直接复制 ZIP 中的分频、PAD、地址或 reset 位号；在首次总线事务时只发一个字节并检查 FIFO/WORK/中断，严禁连续盲发。

