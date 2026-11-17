# CY63300 V139 冷启动 I²C 判别实验

## 实验问题

上轮用写前切换 SBA 地址的方式，已成功配置 I²C 并直接使能 OLED 地址 0x3C。发送控制字 0x00 后，TX_NUM 持续为 1，WORK=1、DATA=0、RAW=0。ARM 样例在发送前将 PB2/PB3 设为高驱动。本机只在卡住后补过高驱动，FIFO 没有恢复。

V139 选择 **在首次发送前设 PB2/PB3 高驱动**。沿用 V136 的地址、分频、引脚和单字节，PAD1 留在冷启动默认复用，PAD0/JTAG TDI 保持原样。对照来自 V136 历史实测，V139 从完整冷启动重建 GPIO 基线，因此若结果改善，后续应做 DRIVE=0 的同流程冷启动对照，再归因给 DRIVE。

## 1. 冷启动和 GPIO 输入检查

OLED 与 JTAG 接线维持现状，使用既有 100 kHz 配置。一轮会话核对指定 DAPLink、唯一 TAP、IDCODE 0x1E200A6F、DMSTATUS 和 SBCS。CPU 若 running，最多 Halt 一次并确认。要求 PERI_CLKEN 与 PERI_RST 各连续三读为 0。若当前状态不符，停止并保存现场。

写时钟前先读不同地址 PERI_RST。GPIO 时钟打开后核对 GPIOB DIR/AFR1/SPEED 和各待修改寄存器冷启动值，确认整字写只改变预定字段。内部上拉配置前后，在 DIR=0、AFR1=0 时分别取三次 GPIOB_IDR，按掩码 0xC 判断 PB2/PB3。上拉后两位必须稳定为高才继续。该检查覆盖芯片的 GPIO 数字输入，OLED 插座电平和 I²C 复用后的总线仍待独立验证。输入检查通过后，先设置开漏和释放锁存，再改 DIR 和 AF。

## 2. 固定写入顺序

所有地址均为 32 位 MMIO。除首次时钟写，普通写入用已经上时钟的 GPIOB ODR 做写前地址切换，写 ODR 时改读 DIR。写后等 SBA 完成、检查错误，再以独立读事务核对。对有保留位的 MODULE_CTRL 预期读回如下。各写入点只执行一次。

| 顺序 | 寄存器 | 地址 | 目标值 | 预期读回 |
|---|---|---|---|---|
| 1 | PERI_CLKEN，先开 GPIO | 0x4002180C | 0x1 | 0x1 |
| 2 | GPIOB_PUPD，内部上拉 | 0x4000015C | 0x300 | 0x300 |
| 3 | GPIOB_OSOD，开漏 | 0x40000158 | 0xC | 0xC |
| 4 | GPIOB_ODR，释放锁存 | 0x40000100 | 0xC | 0xC |
| 5 | GPIOB_DRIVE，高驱动 | 0x40000164 | 0xC | 0xC |
| 6 | GPIOB_DIR，PB2/PB3 输出 | 0x40000104 | 0xC | 0xC |
| 7 | GPIOB_AFR1，PAD8/PAD9 AF3 | 0x40000168 | 0x6C0 | 0x6C0 |
| 8 | PERI_CLKEN，保留 GPIO 并开 I²C | 0x4002180C | 0x21 | 0x21 |
| 9 | CLK_DIV0 | 0x40002810 | 0x3E7 | 0x3E7 |
| 10 | CLK_DIV1 | 0x40002814 | 0x3E7 | 0x3E7 |
| 11 | MCTR，沿用 V136 | 0x40002828 | 0x0 | 0x0 |
| 12 | HOLD | 0x40002838 | 0x5 | 0x5 |
| 13 | MODULE_CTRL，启用 FIFO | 0x40002800 | 0xC | 0xE |
| 14 | MODE，主机 | 0x40002820 | 0x1 | 0x1 |
| 15 | ADDR，7 位 OLED 地址 | 0x40002824 | 0x3C | 0x3C |
| 16 | MODULE_CTRL，使能控制器 | 0x40002800 | 0xD | 0xF |
| 17 | TX FIFO，单个 OLED 命令控制字 | 0x40002808 | 0x00 | 通过 FIFO_STA、I2C_STA 和 RAW 观察 |
| 18 | MCTR，条件 STOP | 0x40002828 | 0x2 | 通过 WORK、FIFO 和 RAW 观察 |

第 8 笔后先确认 PERI_RST=0、MODULE_CTRL=2、FIFO_STA=5、I2C_STA=0、RAW=0。第 17 笔前重新核对配置，要求 MODULE_CTRL=0xF、ADDR=0x3C、FIFO_STA=5、I2C_STA=0、RAW=0 和 DRIVE=0xC。复用切换后，GPIO 输出态 IDR 不作物理电平判据。

## 3. 首字节结果和停止分支

FIFO 单写一次后，最多采样 60 组 FIFO_STA、I2C_STA、RAW，并记录时间戳与 SBA 状态。三寄存器按顺序读取，可能漏采瞬态，不能据单次快照认定状态严格同时发生。

| 观察 | 判定与操作 |
|---|---|
| TX_NUM=1、WORK=1、DATA=0、RAW=0 持续 | 复现卡点。发送前高驱动在本轮仍不足以推进。保留现场，后续再单独测试发送前 PAD1=AF6。 |
| 观察到 DATA=1、TX_NUM=0，且 WORK=1、RAW 无错误 | 控制器已推进并取走字节，允许按 ARM 的成功路径请求一次 STOP。随后只读确认 WORK 是否清零和 FIFO 是否为空。 |
| FIFO 清空且 WORK 已回到 0、无错误 | 记录字节已出队，跳过 STOP。若未看到 DATA，记录采样边界。 |
| NACK、仲裁失败、地址错误或其他意外状态 | 记录原始状态并停止。NACK 是控制器报告的事件，后续优先核对地址/应答；本轮不给错误分支追加写入。 |
| SBCS 错误/超时、调试断连或配置不符 | 记录失败位置和已尝试的目标写入，停止。 |

出队与 STOP/空闲是控制器进展证据。0x00 只有控制字，本轮无法用 OLED 是否亮屏验收，也无法单靠 RAW=0 证明从机 ACK。通过后，下一阶段才使用完整 OLED 控制字和命令序列。

## 4. 授权与记录

- 本轮实物范围为以上最多 16 次初始化写、一次 FIFO 写、一次仅成功分支的 STOP，总计最多 18 次目标 MMIO 写，另允许必要 DMI/SBA 操作及最多一次 Halt。
- 新阶段独立 marker。执行前审核本次 Tcl/包装器和白名单，验证各失败分支不会追加写入。保留全部历史 marker。任一步不符即停止。本轮范围不含软复位、CPU resume、重复发送、Flash/NVR/SRAM 写、自动恢复或断电。
- 执行后保存原始 OpenOCD stdout/stderr、命令、采样和时间、写入计数、SHA256 和结果报告到 Obsidian 的 cy63300自动测试日志目录。
- 方案已核对，实物尚未连接，脚本实物入口待授权后审计。

## 依据

- 本项目 V130、V134、V135、V136、V137、V138 实物报告和日志。
- ARM 样例 D:/project/63300/CY63300_测试样例/IIC_Master.c，117–194、200–289、298 行起。
- 《数字设计文档》PDF 第 146 页 PADMUX 表及 GPIO 输入、I²C FIFO_STA、I2C_STA、MCTR 章节。参考 RTL 模型未提供真实 ASIC 的 I²C FSM。
