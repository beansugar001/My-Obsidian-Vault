# CY63300 芯片测试 · 通宵梳理报告组（总索引）

> 生成时间：2026-09-27 凌晨（通宵任务）
> 材料来源：`D:\project\新建文件夹`（数字设计文档.pdf、测试技术报告.docx、ESUHM339A-B全绑定图.pdf、ESUQFN32008封装加工.pdf、原.epro2、test.zip）
> 关联旧材料：`D:\project\63300`（Keil 测试样例、安全升级固件、CY63300芯片测试文档.docx）、[[2026-09-26 CY63300项目记忆]]

---

## 一句话结论

**这颗芯片是杭州旗捷 CY63300 安全 SoC**（110nm 工艺，裸片 2.05×1.49mm），同一套数字系统有 **ARM Cortex-M0+ / 玄铁 E902 / tiny_riscv（杭电）三种 CPU 版本**，由片内 NVR 里的 `cpu_sel` 字段选择（=0x5A 时选 tiny_riscv）。你手头这批材料（测试技术报告 + test.zip）对应的是 **tiny_riscv 版本**；上一批材料（Keil 样例）对应 **ARM 版本**。两批材料的外设、寄存器地址、引脚完全同一张地图。

## 报告目录

| 文件 | 内容 | 适合什么时候读 |
|---|---|---|
| [01-芯片总览](01-芯片总览-从零认识CY63300.md) | 这颗芯片是什么、里面有什么、怎么跑起来（纯小白向） | 醒来第一篇，20分钟 |
| [02-数字设计文档教科书](02-数字设计文档教科书式精讲.md) | 147页设计文档逐章精讲，按教科书方式重写（最大的一份） | 慢慢啃，配合原PDF对照读 |
| [03-引脚与封装大全](03-引脚与封装大全.md) | 裸片焊点→COB邦定板/QFN32→测试板排针，全链条引脚地图 + 复用表 | 接线、查信号、画板时查 |
| [04-I2C排障指南](04-I2C排障指南.md) | I2C 从协议到寄存器到驱动代码到故障清单（含参考驱动） | **最优先读**，直接上手排障 |
| [05-测试计划与软件工程详解](05-测试计划与软件工程详解.md) | 编译烧录调试全流程详解 + 四大类测试的执行计划 | 上机测试当天 |

## 十分钟速览（TL;DR）

### 1. 芯片身份链（今晚挖出来的最重要事实）

```
CY63300（杭州旗捷，安全耗材/加密SoC，110nm，裸片2052×1485µm）
 ├─ CPU 三选一：Cortex-M0+ / 玄铁E902 / tiny_riscv（NVR1 word5 bit[31:24]=0x5A → tiny_riscv）
 ├─ 存储：Flash 256KB @0x00000000（64KB系统+192KB用户）+ NVR0~7 各512B
 │        + DataRAM 128KB @0x20000000
 ├─ 外设：GPIO×3组 / I2C / SPI×2 / UART+LPUART / OneWire / RTC / DMA
 │        + 安全套件：TRNG/HASH(SM3)/PKE(SM2,RSA,ECC)/SKE(SM4,AES,DES)/PUF/CJ_ENC/CJ_DEC/CJ_EFUSE
 ├─ 时钟：内部RCH 16/24/32/48/60MHz（默认16M）+ RCL 32.768kHz，无外部晶振作主时钟
 └─ 封装：QFN32 4×4mm（29根绑定线，脚22/23/24空）或 COB 直接邦在测试板 CJPCBT021-G 上
```

**为什么说测试板这颗是 tiny_riscv 版**：测试技术报告明确写 RV32IM/三级流水/tinyriscv.cfg；test.zip 代码全部 `HDURiscv_` 前缀、用 `mtvec/trap_entry` 中断机制、轮询 `SYS_IRQ_FLAG@0x4002182C`（文档注明"仅RISCV版本的TINY_MASTER"）；而 CY63300 文档 SYSCTL 里的 `fault_rst_en/osc_ch_req/osc_ch_ack` 位注明"RISCV版本特有"。所有外设基地址两版一致。

### 2. 关于"前任 I2C 跑不通"——五个头号嫌疑（详见报告04）

**现场条件（2026-09-27 确认）：不知道卡在哪一步、不知道从机是什么、没有示波器。** 为此已备好专用诊断固件 `D:\project\新建文件夹\test\i2c_diag\`（README 有完整决策树）：串口菜单四招——GPIO 线电平检查、万用表慢翻转验走线、**软件位扫全地址扫描**（绕开控制器，直接切割"电气侧 vs 控制器侧"）、硬件控制器扫描。第一小时就该跑它。

1. **时钟门控没开**：`PERI_CLKEN@0x4002180C` 的 bit5 是 I2C 时钟使能，**复位值=0（关）**。不开它 I2C 寄存器写了也是白写。
2. **引脚复用没配/配错**：I2C_SCL/SDA 不是默认引脚。RISCV 版 PAD0 复位功能是 `jtag_tdi`；I2C 要靠 GPIO 的 `AFR1@偏移0x68` 显式选功能（如 PAD8/9 上 I2C 是 AF 值 3）。还有一条暗规则：**同一 IP 复用在多个 pad 时，pad 编号小的优先**——如果 PAD0/PAD1 也被配成了 I2C 功能，总线会悄悄跑到 PAD0/PAD1 上去。
3. **开漏没开 + 上拉缺失**：GPIO 有独立的开漏配置寄存器 `Gpio_osod_type@0x58`。I2C 是开漏线与，若配成推挽，从机拉不高总线，读出来全 0xFF 或 NACK。外部 4.7k 上拉也要实测在不在。
4. **STOP 语义踩坑**：`I2CM_CTRL.STOP=0` 时发送队列空后 I2CM 会**拉住 SCL 不放**（等更多数据），程序看起来就"卡死"。单次传输必须置 STOP=1。
5. **地址习惯错误**：7bit 地址直接写 `I2C_ADDR=0x50`（前任记忆里已确认），不要自己左移成 0xA0；`I2C_ADDR` 复位值 0x133 是 10bit 模式的残留值，不改就发不出正确的地址字节。

### 3. 硬件底子（今晚从绑定图/封装单/EDA工程里挖的）

- 测试板是**两层结构**：COB 邦定板 `CJPCBT021-G`（裸片 29 个焊点直接邦到板上焊盘 1~29）+ 底板（USB Type-C → CH340C 串口、AMS1117-3.3 稳压、12MHz 晶振、H4/H5/H6/H7 排针、复位按键）。
- H4 是主扩展排针：MISO/MOSI/CLK/CS/**SCL(脚8)/SDA(脚9)**/UART0_RX/TX/PADMUX/RST/XTAL_OUT/XTAL_IN/VDD_IO/GND。H7 是 JTAG 排针：TCK/TDO/TMS/TDI/PAD0/GND。
- 出厂测试要求：所有引脚对 GND 加 -100µA 恒流，二极管压降应在 -1.0 ~ -0.2V —— 这也是你万用表快速查焊点/查线的好方法。

### 4. 工程现状（2026-09-27 更新）

- **完整固件工程在 `D:\project\新建文件夹\test\`**（73 个文件：main.c/scheme.c/start.S/trap_entry.S/link.lds/Makefile + 全套 lib + coremark/benchmarks/spec_benchmarks/vuln_tests）。根目录的 test.zip 只是它的不完整快照，以 test/ 目录为准。
- test.zip 快照与完整工程的差异：快照缺 main.c、scheme.c/h、start.S、trap_entry.S、link.lds、根 Makefile、uart.c、xprintf.c、sm3.c、sbrk.c、utils.c、trap_handler.c、spec_benchmarks/、vuln_tests/；且快照里 `risc_time.c` 是 0 字节（完整工程里有，用 mcycle CSR 实现）。
- 完整工程里同样**没有任何 I2C 代码**（仅中断号枚举 HDURiscv_IRQn_I2C=3）——前任的 I2C 尝试不在这个仓库里。main.c 是协议测试入口（SM3 签名/批量验签/TBF）。
- 已新增 `test/i2c_diag/` 诊断固件（i2c_diag.c + Makefile + README），无示波器排 I2C 用。

### 5. 尚未确认、需要上机核对的开放问题

- [ ] 前任 I2C 卡点/从机型号/地址——用 i2c_diag 的位扫直接回答"总线上有没有活物"
- [ ] 测试板这颗是 tiny_riscv 还是 E902 版？（读 NVR1 word5 或直接看 openocd 是 JTAG-DP 还是 SWD 能否连通）
- [ ] 底板 12MHz 晶振接在 OSCIN/OSCOUT 上，但数字文档只写内部 RCH/RCL——晶振是备用/精度模式还是接错？建议量 OSCIN 有无起振
- [ ] 设计文档目录提到"I2C FeedBack DELAY 说明"但正文缺失（4.4节书签错误），从机时钟拉伸的具体行为只能看 RTL 或实测
- [ ] SDA/SCL 在 COB 板上到底邦到哪两个 PAD（PAD8/9 还是 PAD0/1）——i2c_diag 两组引脚各扫一遍即可确认

### 6. 材料可信度备注

- 数字设计文档目录页书签大量"错误!未定义书签"，目录页码不可用；正文章节实际是 4.1~4.24（I2C 在 **4.19**，SPI 在 4.20），报告02里给了真实章节地图。
- 文档有版本混杂痕迹：功能总表写"4组GPIO"、GPIO 章节写"3组×6脚"（实物 16 个 PAD，3 组是对的）；I/O 复用表 ARM 版和 RISCV 版各一张，查引脚时先确认手里这颗是哪个版本。
- 测试技术报告把 tinyriscv 模板的说明（Boot ROM、telnet、CMSIS-DAPLink）和 CY63300 的寄存器混写，报告05里已把两者分离标注。
