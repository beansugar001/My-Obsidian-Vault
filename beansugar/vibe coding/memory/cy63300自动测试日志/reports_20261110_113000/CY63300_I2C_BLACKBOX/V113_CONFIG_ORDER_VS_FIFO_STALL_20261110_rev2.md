# CY63300 V113：配置顺序与 TX FIFO 卡住复核

日期：2026-11-10

## 结论

配置确实曾有一个容易误判的点，但修正后 TX FIFO 仍卡住：`MODULE_CTRL` 的 bit1 是只读保留位，硬件写 `0x0D` 后读回 `0x0F` 是预期结果；不能要求读回精确等于写入值。V113A2/A3 随后按 ARM 轮询样例的顺序预置 `I2C_ADDR=0x3C`、打开 I2C_EN、向 TX FIFO 写单字节 `0x00`，但 FIFO 计数仍为 1，`I2CM_WORK=1`、`I2CM_DATA=0`、RAW 中断为 0。

因此，当前证据不支持“只是没有先写地址”的解释。它指向主控制器已进入 WORK、但尚未进入 DATA/消耗 TX FIFO 的阶段。究竟是 START/地址阶段、芯片实际地址寄存器语义、SBA 写入触发路径、PAD 上的实际波形还是 ASIC 内部时序，现有证据仍不能区分。

## 协议里“先请求地址”的准确含义

在 I2C 主机事务中，地址阶段在线路上先于数据阶段。但 ARM 轮询驱动并不把 `0x78` 作为普通 payload 写入 TX FIFO：它先调用 `I2C_SetAddr(0x50)` 设置地址寄存器，再使能控制器，之后 `I2C_WrByte(data)` 只把数据字节放入 FIFO。地址方向由主机控制器和地址配置共同产生。

OLED 的 7-bit 地址 `0x3C` 对应线上写地址字节 `0x78`（`0x3C << 1 | 0`）。目前最贴近 ARM 轮询流程的实测是：地址寄存器预置 `0x3C`、使能控制器、TX FIFO 写 `0x00`。不要在没有依据时再把 `0x78` 当 payload 塞入 FIFO；那会把测试变成另一种帧格式，而不是修正地址设置顺序。

手册对 `I2C_ADDR` 的文字称其为 I2CS address，与 ARM 驱动在 Master 模式通过 `I2C_SetAddr()` 设置目的地址的实际用法存在冲突。该文档歧义必须保留为候选根因，不能把任一方当作 ASIC 语义的最终证明。

## 证据矩阵

| 证据 | 实测/源码 | 解释 |
|---|---|---|
| V111 公司 `I2CTest()` 次序 | 控制器使能后设 `ADDR=0x3C`，向 FIFO 写 `0x00`,`0xAF`；最终 TX_NUM=1、WORK=1、未见 DATA | 地址后设、双字节时同样卡住；不证明这两个字节到达引脚 |
| V113A2 模块控制位 | 对 `MODULE_CTRL` 写 `0x0D`，读回 `0x0F`；bit1 是 RO 保留位，读 1 | 这是正确使能值的正常读回差异，不是失败 |
| V113A3 ARM 地址顺序 | 地址先设为 `0x3C`，然后启用控制器，TX FIFO 单次写 `0x00` | 与 ARM 轮询样例顺序一致；仍未排空，故“先设地址”单独不能解决 |
| V113A3 控制器状态 | 轮询最终 STATUS=`0x1`、FIFO=`0x104`、RAW=`0`、GPIO IDR=`0x2C` | WORK=1、DATA=0、TX_NUM=1；采样 GPIO 为高只代表采样值，不能代替引脚波形 |
| V113A3 STOP 尝试 | TX 超时后对 MCTR 写 `0x2`，独立读回为 `0`；原始日志显示发生过一次写尝试 | 不能判为 STOP 已生效；结果 JSON 的 STOP_WRITE_COUNT=0 是计数器在读回成功后才递增造成的低估，实际目标写尝试共 2 次（FIFO、MCTR） |
| V112 GPIO 地址探测 | 软件 GPIO 发出 `0x3C` 地址帧，第九拍读到 NACK | 从机 ACK 尚未确认；没有连接器端示波器波形，不能单凭 NACK 断言 OLED、接线或地址有问题 |
| V7.7 CPU-store 对照 | SRAM CPU store 阶段曾运行到 store 尝试，但结果 `CPU_STORE_FAIL_OR_UNKNOWN_SRAM_RESTORED`；Progbuf 单测未确认执行 | 当前没有可靠证据表明 CPU 单条 store 已通过；不应直接用未验证的 progbuf 路径写 I2C FIFO |

## 对“配置问题”的判断

已验证/较强证据：I2C 时钟开启并读回；复位位为 0；Pad8/Pad9 配成 GPIOB2/B3 AF3、开漏并释放；分频写为 ARM 参数换算后的 `DIV0=0x0F`、`DIV1=0x23`；Master 模式、FIFO 使能和 I2C_EN 可读回；地址设置顺序已经按 ARM 轮询样例做过。

尚未证明：控制器实际在 Pad8/Pad9 上产生 START/SCL/SDA；OLED 实际 ACK；`I2C_ADDR` 在该 RISC-V 芯片里的 Master 目的地址语义与 ARM 驱动完全相同；TX FIFO/SBA 组合访问能触发真实 ASIC 内部读出。

当前最准确的描述是：**初始化配置读回基本成立，事务启动/地址阶段没有得到进展证据。** 不宜继续随机扫地址、反复改分频或在活动状态下重复写 STOP/FIFO。

## 下一步：通过 CPU 执行路径与 SBA 做差分

目标是只改变写入发起者：相同的一套 Pad、时钟、分频、模式、地址、FIFO 使能，仍只发送一字节 `0x00`，但让 RISC-V CPU 通过 `volatile` store 写 TX FIFO；OpenOCD 只负责装载到已验证的 RAM 执行区、启动代码和读取 RAM 邮箱。这样比较：

1. CPU-store 后 FIFO 是否排空、WORK/DATA 是否变化、是否产生地址 NACK/STOP 状态。
2. 若 CPU-store 成功而 SBA-store 卡住，重点转向 SBA→APB 副作用访问路径。
3. 若 CPU-store 也卡住，SBA 通用写入基本不再是首要嫌疑；再按 START/地址语义、PAD 波形、芯片版本差异查。

**准入条件：** 当前芯片仍保留 V113A3 的 WORK=1、TX_NUM=1 状态。必须先由用户断开并重新上电/重新插拔，清空现场；之后新阶段从只读基线开始。下一轮先在 RAM mailbox 固件中加入单次 CPU-store 路径，离线编译和审计；实物运行时不得 Flash/NVR 烧写，不自动复位或重试。当前可复用的 CPU-store/progbuf SRAM 测试未通过，因此先核实旧 V77/V93 RAM 执行方案的执行与返回证据，再决定是否允许向 I2C MMIO 发出 CPU store。

若不能建立可信的 CPU 执行/结果回传，就停止该差分实验；不要把“代码已装载”当作 CPU 已执行。可替代的判别证据是示波器在 OLED 连接器端捕获 START、SCL 时钟及地址/ACK，但这不改变当前寄存器配置。

## 原始日志与 SHA256

V113A2 和 V113A3 的完整综合日志 SHA256：

- V113A2：`27850717BD40957EA27E4F675CC9BDEABC120E105D095AE6AD9B647A2FB4CD38`
- V113A3：`5DA721B8B1EBE422DB3F753357C4A2C0CD02BCB1CBD0B120E571827CABA726EF`
- V113A5 只读收尾：`617CBE4BE70B8CE06FD81A0F13BB1013477272A5E6ED0C0D3E4D39C25C63D380`

V113A3 实际目标 MMIO 写尝试：2 次；其中 TX FIFO `0x40002808 <- 0x00000000` 一次，MCTR `0x40002828 <- 0x00000002` 一次。V113A5 收尾只读，写入次数 0。全部日志及阶段 marker 均保存在 `runs_local_v109` 与 `markers`，未删除或复用。

已归档副本（含阶段 stdout/stderr/combined logs、JSON、marker、脚本和 Tcl）位于：
`D:\Obsidian\notes\笔记\beansugar\vibe coding\memory\cy63300自动测试日志\reports_20261110_113000\CY63300_I2C_BLACKBOX`
文件哈希清单为该目录下 `SHA256SUMS.txt`。原始工作区文件和 marker 保持不变。

## 来源

- [RISC-V 寄存器流程与 ARM 差异](../02_REGISTER_FLOW.md)
- [IIC_Master.c 轮询式 Master 流程](D:/project/63300/CY63300_测试样例/IIC_Master.c:200)
- [ARM I2C_MasterInit 与 I2C_SetAddr/I2C_WrByte](D:/project/63300/CY63300_测试样例/Device_lib/src/cj32l01xx_i2c.c:205)
- [数字设计说明提取：MODULE_CTRL、TX_FIFO、I2C_ADDR、MCTR、STATUS](../manual_extracts.md)
- [旧诊断工程里保留的两种帧格式假设](D:/project/RISCV-63300/test/i2c_diag/i2c_diag.c:365)（仅表示历史假设，不作为正确流程依据）

