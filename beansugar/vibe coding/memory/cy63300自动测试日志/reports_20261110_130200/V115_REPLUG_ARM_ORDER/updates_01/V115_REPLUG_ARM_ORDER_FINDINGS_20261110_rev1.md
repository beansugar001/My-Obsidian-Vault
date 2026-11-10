# CY63300 V115：重插后配置顺序与单字节事务结果

日期：2026-11-10（Asia/Shanghai）  
范围：重插后只读基线、GPIO/I²C 时钟配置、ARM 顺序对照、单字节 FIFO 观察。  
仪器：本轮未连接示波器；所有“总线是否有波形”均未被本轮直接观测。未烧录固件。

## 结论

本轮确认了一个真实的配置顺序差异：在当前 RISC-V 实物上，先将 `ADDR` 写成 OLED 地址 `0x3C`、再把 `MODULE_CTRL` 写成 `0x0D`，读回为 `0x0E`，`I2C_EN` 位没有置起；先写临时地址 `0x50`、置 `I2C_EN` 后再改成 `0x3C`，则读回 `MODULE_CTRL=0x0F`，控制器空闲。该结果与 ARM 轮询样例的“先 `I2C_SetAddr`、后 `I2C_Cmd(ENABLE)`”顺序不一致，必须作为芯片版本/寄存器语义差异继续查证。

按后一种顺序使能后，向 TX FIFO 写入一个 `0x00`，FIFO 仍为 `TX_NUM=1`，状态为 `WORK=1, DATA=0`，RAW 中断为 0；本轮没有出现控制器消费 FIFO 字节的证据。脚本没有继续重写 FIFO、没有发 STOP，也没有复位。因此，“使能顺序”是已发现的问题，但**尚不足以解释或解决 FIFO 停滞**。

## 本轮实测

| 阶段 | 动作 | 结果 | 目标写入数 |
|---|---|---|---:|
| V115A | 新建独立重插后只读基线；一次 halt；读取 PERI_CLKEN/RST 各三次 | IDCODE `0x1E200A6F`，DMSTATUS `0x00430382`，SBCS `0x20040404`；CLKEN=`0`、RST=`0`。时钟关闭，按门禁跳过 I²C 内部寄存器读取 | 0 |
| V115B | 开 GPIOB/I²C 时钟 | 单次写 `0x4002180C <- 0x21`；三次读回 `0x21`，RST 仍为 0 | 1 |
| V115C | Pad8/Pad9 释放式开漏 AF3 | ODR=`0xC`、OSOD=`0xC`、DIR=`0xC`、AFR1=`0x6C0` 均读回；IDR=`0x2C`，Pad8/9 输入采样为高；I²C 仍禁用、空闲 | 4 |
| V115D | ARM 顺序：配置 H/L=1000（寄存器 999）、MCTR、HOLD、FIFO、Master、ADDR=`0x3C`，最后置 I²C_EN | 前 7 项写入和读回成立；`MODULE_CTRL <- 0x0D` 后读回 `0x0E`，bit0 仍为 0，脚本立即停止，未写 TX FIFO | 8 |
| V115E | 使能顺序对照：先临时 ADDR=`0x50`，再置 I²C_EN，最后 ADDR=`0x3C` | `MODULE_CTRL=0x0F`，ADDR=`0x3C`，FIFO 空、WORK=0、RAW=0；没有启动事务 | 3 |
| V115F | 在上述使能顺序下写一次控制字节 `0x00` | FIFO=`0x104`（TX_NUM=1），STATUS=`0x1`（WORK=1、DATA=0），RAW=`0`；无 NACK、无 FIFO 消耗。未发 STOP | 1 |

各阶段均确认唯一 TAP、指定 DAPLink 序列号 `07000001006700343500000a4e57354aa5a5a5a597969908`、CPU halted、DMSTATUS halted、SBCS 无 busy/error。每阶段最多一次 halt；没有 CPU resume、软件复位、断电、Flash/NVR、CPU store 或自动重试。

本轮合计目标 MMIO 写尝试 **17 次**：时钟 1、GPIO 4、V115D 8、V115E 3、V115F 1。TX FIFO 写入 **1 次**；STOP 写入 **0 次**。V115D 的八次写包括最后一次 `MODULE_CTRL=0x0D`，但其 bit0 读回仍为 0。

## 根因判断更新

| 假设 | 当前证据 | 判断 |
|---|---|---|
| 重插后外设时钟没有开 | V115A 的 CLKEN=0；V115B 写 0x21 后读回成立 | 重插后的初始状态确实需要重新开时钟；这是预期初始化项，不足以单独解释过去已配置状态下的 FIFO 停滞 |
| ARM `ADDR` 在 I²C_EN 前写入的次序可直接照搬 | V115D 在 ADDR=0x3C 时 I²C_EN 未置位；V115E 换成先启用、再写目标地址后成功 | 当前实物不支持把 ARM 示例顺序不加验证地照搬；存在次序或使能时的地址条件差异 |
| 只有 I²C_EN 顺序导致 FIFO 不消费 | V115E 使能成立；V115F 仍是 TX_NUM=1、WORK=1、DATA=0、RAW=0 | 已反证“只改 I²C_EN 顺序就能跑通”；仍有事务启动/地址阶段/写入触发问题 |
| SBA 通用写路径完全失效 | 时钟、GPIO、分频、模块控制等寄存器读回变化；TX FIFO 计数从空变为 1 | 通用写路径并非全失效；但这不证明 FIFO 内部数据或外设事务真正提交 |
| FIFO 内容已进入 I²C 移位流程 | TX_NUM 仍为 1、DATA 始终 0，RAW=0 | 当前没有证据证明数据已被控制器消费 |
| Pad8/9 已产生实际 START/SCL/SDA | 仅有 GPIO 输入采样 `0x2C`；未接示波器 | 未证实。静态高电平采样不能证明短脉冲存在或不存在 |

### 关键资料差异

- ARM `IIC_Master.c`：`I2C_MasterInit()` 后 `I2C_SetAddr(0x50)`，再 `I2C_Cmd(ENABLE)`，之后才写 TX FIFO；源文件约 200–274 行。
- ARM `cj32l01xx_i2c.c`：MasterInit 写 DIV0/1、MCTR、HOLD、FIFO enable、MODE；`I2C_Cmd` 置 `I2C_EN`；`I2C_SetAddr` 直接写 ADDR；函数约 205–235、272–317 行。
- 数字设计说明：`I2C_ADDR` 章节称该寄存器供 I²CS 地址使用（4.19.8）；TX_FIFO 章节定义 bit9 RESTART、bit8 R/W、bit7:0 数据（4.19.2）；I2CM_CTRL 的 STOP=0 表示 TX FIFO 空时保持 SCL 低（4.19.9）。这些描述与 ARM Master 驱动使用 `I2C_ADDR` 设置目标地址之间存在需要厂家确认的语义差异。
- 目前没有真实流片 I²C IP RTL。现有 V33 `i2c_behavioral_mmio.v` 明确是行为 mock，并假设两次 TX_FIFO 写（地址+W、payload）才启动；此假设不能作为实物协议依据。

## 下一步建议

优先做 **SBA 与 CPU store 的差分**，而不是继续扫分频/地址：当前 SBA 已能打开时钟、改 GPIO、改 I²C 配置，且 FIFO 计数增加，但事务没有推进。若 CPU 自己写同一配置与同一 TX_FIFO 后能消费，问题落向 SBA/RIB 对 FIFO 副作用写的提交语义；若 CPU store 也停在同样状态，再集中调查 START/目标地址语义、Pad 输出路径及实际波形。

CPU 执行路径此前未被验证：PROGBUF0 写后读回为 0、postexec 未执行；RAM 装载成功也未证明 CPU 能从 RAM 运行。因此若用固件进行 CPU store 对照，需要先以只读方式备份并校验当前主 Flash，核对启动地址/链接地址/分区，并生成只写邮箱结果、不写 NVR 的最小固件。当前工程规则禁止 Flash 擦除；本轮虽获得用户“允许烧录”的概括授权，但执行前仍需确认实际可用的**非全片擦除**编程路径，不能使用包含 Flash 擦除模式的 `flash.bat`。

编译器调查：当前 `PATH` 未找到 `riscv-none-embed-gcc`、`riscv32-unknown-elf-gcc` 或 `riscv64-unknown-elf-gcc`；在 `D:\` 和 Visual Studio 目录的定向搜索也没有找到这些编译器或 `clang.exe`。工程内有历史 `i2c_diag.bin/.elf`，但它不是本轮 CPU-store mailbox 测试固件，不能拿来冒充验证结果。

当前目标状态：时钟开、Pad8/9 配置已写、I²C_EN=1、ADDR=0x3C、DIV0/DIV1=999、HOLD=5、MCTR=0；TX FIFO 中留有一个 `0x00`，控制器 WORK=1、DATA=0。不要在这个状态下再加 FIFO 字节或发 STOP；下一轮先做 CPU-store 路径的离线构建和 Flash 安全路径审计，或由用户重新插拔后再开始新实验。

## 原始证据与哈希

所有阶段的 command.json、result.json、OpenOCD stdout/stderr/combined log 和一次性 marker 保存在工作区 `runs_local_v109` 与 `markers`。

| 阶段 | combined 日志 SHA256 |
|---|---|
| V115A | `74B302377A80A59F52F0EBBB82B6D4EA03DA3FB136AECC7A50D0013339C396AE` |
| V115B | `987FE493899EA22C41EB2E0A1016CB465B36F1E8681DB33E9A931D407BF88895` |
| V115C | `8C7F242B5DF6D4C6A17743CF9F3000A738447A2443DFA95E9C17D3FB312B5651` |
| V115D | `FA8CE7A779B982F664E6D5F93BB6E53A374EB4BCDC9DB8025F60F41774A03724` |
| V115E | `9A8B190C717F7752817A0A06BC0F0DC5331F38D61FCD27E0315D7EDCF53339EA` |
| V115F | `EE4FB81B006B999B068F6977F16F83113DFD3D6A9AC22077C440E03D4E2FA609` |

脚本与 Tcl：

- `run_v115a_post_replug_baseline.py` / `v115a_post_replug_baseline.tcl`
- `run_v115b_enable_gpio_i2c_clock.py` / `v115b_enable_gpio_i2c_clock.tcl`
- `run_v115c_pad8_pad9_arm_pin_setup.py` / `v115c_pad8_pad9_arm_pin_setup.tcl`
- `run_v115d_arm_order_oled_single_byte.py` / `v115d_arm_order_oled_single_byte.tcl`
- `run_v115e_enable_before_final_address.py` / `v115e_enable_before_final_address.tcl`
- `run_v115f_single_byte_after_enable_addr.py` / `v115f_single_byte_after_enable_addr.tcl`
