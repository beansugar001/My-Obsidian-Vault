# V111：按公司 I2CTest 顺序推进 OLED 测试

日期：2026-11-10

## 本轮目标

以公司 `CY63300.c::I2CTest()` 的初始化顺序为参考，在目标重新上电后先建立干净寄存器基线，再试一笔 OLED 命令帧。目标是区分“初始化/配置差异”与“TX FIFO 仍不能消费”，逐步接近显示 Hello。

## 执行顺序与门槛

| 阶段 | 动作 | 放行条件 | 停止条件 |
|---|---|---|---|
| V111A0 | 新的只读门禁：TAP、CPU、DM/SBCS、CLKEN/RST | 目标及调试器正确；复位为0；CLKEN为干净上电状态 | PASS；写入0 |
| V111A1 | 一次写 GPIO/I²C 时钟 `0x4002180C <- 0x21`，之后独立读取控制器默认状态 | 写后 CLKEN=0x21、RST=0；控制器/FIFO idle | PASS；写入1 |
| V111A2 | RISC-V Pad8/9 AF3 开漏配置和读回 | AFR1/OD/DIR/IDR符合预期 | PASS；写入4 |
| V111A3 | 按公司 `I2C_MasterInit` 顺序配置 DIV0/1、MCTR/HOLD、FIFO、Master，I2C_EN 保持关闭 | 逐项读回正确，FIFO 空 | PASS；写入6 |
| V111A4 | 使能 I²C，再设 OLED 7-bit 地址 0x3C | FIFO/WORK/RAW/线路状态正常 | PASS；写入2 |
| V111A5 | 发送 OLED `0x00,0xAF` 控制帧，排空后才请求 STOP | TX count 排空、WORK 返回空闲、STOP 标志 | FAIL；60 次轮询仍 STATUS=1、FIFO=0x104 (TX_NUM=1)、RAW=0；未请求 STOP、没有再发写入 |

## 与公司 `I2CTest()` 的映射

- 采用其调用顺序：先准备 GPIO；驱动开启 I²C 时钟；配置 DIV0/DIV1、MCTR、HOLD、FIFO、Master；之后使能、写地址、写 FIFO。
- 不复制其 PB0/PB1 AF2 推挽设置；当前板级映射是 Pad8/9 = GPIOB2/3 AF3 开漏。
- 公司 H/L=`0x10/0x24` 经驱动减一后对应 DIV0=`0x0F`、DIV1=`0x23`；本轮按公司值试验，并以实物读回/状态为准，不推断真实 SCL 频率。
- 公司函数地址 `0x55` 和负载 `11 22 33 44` 不适用于 OLED；改用有模块资料支持的 7-bit `0x3C` 和 SSD1306 命令控制字 `0x00`、显示开命令 `0xAF`。
- 不复制其“FIFO 未完成即关 I²C 时钟”的结尾；单帧须等数据排空，显式请求 STOP，并观测 NACK/STOP/WORK。

## 当前进度

V111A0 已实际完成：IDCODE=`0x1E200A6F`、DMSTATUS=`0x00430382`、SBCS=`0x20040404`；CPU 初始 running，本阶段 halt 一次后 halted；CLKEN/RST 读取为 CLOCK_OFF / RESET_CLEAR；目标 MMIO 写 0。因时钟关闭，未读取 I²C 内部寄存器。

V111A0–A4 已 PASS；V111A5 失败并已停止。当前事务仍处于 WORK，FIFO 仍有一个字节；不要再发 FIFO 数据或在此状态修改控制器。先完整断电重上电，再开新只读阶段。下一项判别建议是独立于 I²C IP 的 GPIO 开漏位模拟地址 ACK 测试；本轮未执行。

## 安全边界

不写 Flash/NVR，不复位，不自动重试，不自动恢复，不自动断电。实物事务失败后留存现场并停止；OLED 初始化和 Hello 只能在单帧确认完成后继续。
