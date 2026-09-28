# Notes: TinyRISC-V UART/I2C 板级调试

更新时间：2026-09-28（Asia/Shanghai）

## 目标
定位 CY63300 / TinyRISC-V 板上发送 UART 字符 `d` 后串口助手无输出、并继续验证 I2C/OLED 的问题。当前目标先确认固件是否启动以及 UART 收发是否工作，再决定是否进入 I2C 总线诊断。

## 板卡与环境
- 工作目录/工具：`D:\project\tools\tinyriscv-master\tools\openocd`
- OpenOCD：0.10.0+dev-00914-g4cb81306a-dirty (2020-01-28)，CMSIS-DAP/JTAG，10 kHz。
- JTAG TAP ID：`0x1e200a6f`；OpenOCD 能识别 1 个 RV32 hart；日志给出 `datacount=3 progbufsize=1`。
- 串口助手：COM6，USB-SERIAL CH340，设备管理器状态 OK；115200/8N1。用户已核对 EDA 信号通路和接线，并确认 OLED 已连接到 H2 且上电。不要重复要求用户确认接线或 COM 号，除非出现新的反证。
- 项目固件：`D:\project\新建文件夹\test\i2c_diag\i2c_diag.c`。固件菜单有 `[d]线电平 [a]慢翻转 [b]位扫 [c]硬件扫 [r]全跑`；`main()` 用单字节小写命令分派，`d` 无需 CR/LF，执行后用 xprintf 打印 SCL/SDA 电平等内容。

## 已确认结果
### JTAG / CPU
- 多次能够识别 TAP、读取 hart 和内存映射寄存器，说明 JTAG 基本通信存在。
- 曾读 `reg pc` 得到 `0x00000000`，且一次 `resume; sleep 1000; halt; reg pc` 仍为 0。是否 CPU 真正开始执行、该读数是否代表当前执行 PC，尚未最终确认。
- 最近执行 `reset run; sleep 1000; halt; mdw 0x40003C08 1; resume; shutdown`。复位过程中出现 `JTAG scan chain interrogation failed: all zeroes`，但后续内存读取成功，UART 控制寄存器读到 `0x00000003`。这说明这次读取时 UART_CTRL 为 3；不能单凭该值证明应用已运行。

### UART
- 先前串口助手发送区/接收区曾显示 `ABC123`，但该显示是否是目标固件回显、串口助手本地显示或其他回环行为未独立确认。
- 曾测得 UART 控制寄存器 `0x40003C08` 为 `3`，状态/数据寄存器的历史读数包括 `0x40003C04=0`、`0x40003C10=0x8B`（当时语境不足，不能据此断定 RX/TX 状态）。
- 近期通过 DMI/SBA 尝试把 UART_CTRL 写为 0，读回 0；随后同一流程尝试恢复为 3，仍读回 0。再执行 `reset run` 后 `mdw 0x40003C08` 读到 3。暂时将“reset 后 UART_CTRL=3”作为当前状态，不把此前 SBA 写入的状态字段当作可靠成功/失败标志。
- 当前待办：串口助手保持 COM6/115200/8N1 打开，清空接收区，在最近一次 reset run 后只发一个小写 `d`（不追加回车/换行），检查是否有上电菜单或 `[d]` 线电平输出。这个复测尚未收到结果。

### DMI / System Bus Access (SBA)
- `riscv dmi_read 0x38` 得到 `0x20040404`。按标准 SBCS 字段看，报告 sbversion=1、sbasize=32、支持 32 位访问。
- 直接 DMI/SBA 读取 `0x4002180C` 成功，SBDATA0 (`0x3C`) 返回 `0x101`；这与之前 `mdw` 读数一致，证明读取路径能读到该地址。
- 直接 SBA 尝试写 `0x4002180C=0x121`，随后读回仍为 `0x101`，I2C 时钟使能位未证实可写。
- 本地 `D:\project\tools\tinyriscv-master\rtl\debug\jtag_dm.v` 的 `sbcs` 初始化为 `0x20040404`；对 SBCS 写入直接 `sbcs <= data`；源码可见 SBDATA0 读取 `dm_mem_rdata_i`、写入会拉高 `dm_mem_we`。这份 RTL 没有实现标准 SBCS `sbbusy/sbbusyerror/sberror` 的完整状态更新，因此 OpenOCD 输出里这些位为 0 不能当作事务成功的凭据。该仓库 RTL 和目标板映像是否完全同版本仍是限制，但 DMI 默认值、datacount/progbufsize 与它吻合。

### I2C / OLED
- 芯片手册图示：I2C 模块基址 `0x40002800`。MODULE_CTRL offset 0，bit0 I2C_EN、bit2 TX FIFO enable、bit3 RX FIFO enable；TX FIFO offset8；FIFO_STA offsetC；DIV0/DIV1 offset10/14；MODE offset20；I2CM_CTRL offset28；I2C_STA offset3C；RAW_INTR_STA offset58。
- 之前读 GPIOB 输入寄存器 `0x40000150` 曾得到 `0x2C`，对应 GPIOB.2/.3 高电平；当时用弱上拉和输入配置。仅证明读取时引脚是高电平，不代表 I2C ACK 或时钟波形正常。
- 之前 I2C FIFO/status/raw 状态读数多为 0；若外设时钟未打开或写操作未生效，这些读数不能证明控制器损坏。
- 代码审查发现 `i2c_diag.c` 原硬件 probe (`hw_probe`) 将 `I2CM_CTRL=2`（STOP=1、SBYTE/START=0），且把 `I2C_ADDR` 当作从机目标地址使用；手册却称 I2C_ADDR 是 I2C 从机地址。因此先前硬件扫结果不可靠，不能用来判断 OLED 或连线故障。
- 更合适顺序：UART `d` 输出先确认；随后跑 `b` 软件 GPIO 开漏位扫（绕过 I2C 控制器）；若软件扫描有 ACK，再修正硬件 I2C START/地址序列跑 `c`。软件扫无 ACK 时再依据输出查上拉、引脚 AF、OLED 电源/地址。

## 不要重复的无效方向
- 不要再让用户反复截图证明已点发送、确认 COM6 或重查 EDA 接线；用户已经明确做过。
- 不要把 `mdw/mww` 对 SYSCTL/I2C 的结果直接当作可靠外设写入证据；当前还在验证写路径。
- 不要把 SBCS 清零错误位解释为 SBA 成功。
- 不要再重复同样错误的 I2C `STOP`-only probe。
- 未经用户明确授权，不擦除或写入 Flash，也不重新烧录固件。

## 当前状态 / 下次行动
1. 当前寄存器观察：reset run 后 UART_CTRL=`0x3`。
2. 等待/核对用户在该状态下发送单个小写 `d` 的结果；固件解析无需 CR/LF。
3. 若串口仍空：先判定启动和 UART TX/RX（结合 reset 后的 PC、UART 状态/接收数据；避免盲读会弹出的 RX FIFO），再决定修复串口还是测 I2C。
4. 若 `d` 能输出：直接执行 `b` 软件位扫；记录发现的 ACK 地址，再测试硬件 I2C。
