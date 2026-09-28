# CY63300 JTAG 排查经验

## 结论

2026-09-27 最终在 10 kHz JTAG 下成功连接 CY63300：

```text
JTAG tap: riscv.cpu tap/device found: 0x1e200a6f
Examined RISC-V core; found 1 harts
hart 0: XLEN=32
Listening on port 3333 for gdb connections
Listening on port 6666 for tcl connections
Listening on port 4444 for telnet connections
```

这证明 DAPLink、JTAG TAP、RISC-V DMI 和核心访问最终都能工作。之前反复出现的 `all zeroes` 主要应按接触、跳线、供电状态或复位状态不稳定排查，不能直接认定为 Flash 永久损坏。

## 正确 JTAG 接线

```text
DAPLink SWCLK/TCK -> U5-1 TCK
DAPLink TDO       -> U5-2 TDO
DAPLink SWDIO/TMS -> U5-3 TMS
DAPLink TDI       -> U5-5 TDI
DAPLink GND       -> U5-6 或 U5-10 GND
DAPLink nRESET    -> U5-8 RST（可不接；本次成功时未接）
U5-7             -> VDD_IO（板子由 Type-C 供电时，不把 DAPLink 3V3 当作并联电源）
U5-4、U5-9       -> NC
```

测试板 H8-1 与 H8-2 需要短接以选择 JTAG 路径。U5 方形焊盘为 1 脚方向。

## OpenOCD 配置和现象判断

推荐先用 10 kHz：

```powershell
cd "D:\project\tools\tinyriscv-master\tools\openocd"
.\openocd.exe -f .\tinyriscv_10k.cfg
```

`all zeroes`、`IR capture error 0x00`、`dtmcontrol is 0` 表示 JTAG 扫描阶段没有得到有效目标数据，优先检查接触、H8、TDO/TCK、目标供电和复位状态。

出现：

```text
JTAG tap found
```

说明 JTAG 扫描链已经恢复。随后出现 DMI 超时，才进入 RISC-V Debug Module/核心状态排查。`riscv set_command_timeout_sec` 只能延长等待，不能修复扫描链。

本次测试发现 `connect_assert_srst` 会导致：

```text
Connecting under reset
JTAG scan chain interrogation failed: all zeroes
```

因此本芯片不要优先使用 `connect_assert_srst`。nRESET 线不是基本 JTAG 扫描必需线，本次保持断开反而成功；若要接回，必须先停止 OpenOCD 并断电重连。

## Flash 擦除教训

曾执行过：

```text
mww 0x40022000 0x00000003
mww 0x00000000 0x12345678
```

根据设计文档，`rwe_sel=11` 为 Chip 擦除，向主 Flash 地址写入触发擦除，范围为：

```text
0x00000000 ~ 0x0003FFFF
```

即主 Flash 的 system memory 64 KB 加 user memory 192 KB，共 256 KB。向主 Flash 地址触发时，不等同于擦除 NVR；向 NVR 地址触发才会擦除 NVR+Chip。

随后 `i2c_diag.bin` 曾成功写入 `0x00000000` 并校验通过，但以后不得未经明确确认再次执行全片擦除、扇区擦除或 Flash 写入。

## 操作纪律

- 先确认 JTAG TAP 能识别，再进行任何后续操作。
- OpenOCD 报错时不要反复擦除 Flash。
- 发现 `all zeroes` 时先断电、重插 U5/DAPLink、确认 H8-1/2，再换速度。
- 保持已经成功的线缆状态，不要在 OpenOCD 运行中插拔 nRESET 或电源线。
- 当前成功状态应记录为：Type-C 给测试板供电、DAPLink USB 接电脑、H8-1/2 短接、JTAG 五线加 GND、nRESET 暂不接、DAPLink 3V3 暂不接、10 kHz。
 
## 2026-09-27 UART 启动排查阶段性结论
 
### 已确认
- H12/H13 网络表：H12-1=CH340C_TXD，H12-2=CH340C_RXD；H13-1=CY63300_UART0_TX，H13-2=CY63300_UART0_RX。正确接线为 H12-1→H13-2、H12-2→H13-1；不能把同一接口两脚短接。
- H10 网络：1=TDI，2=PAD0，3=NET6；H8：1=VDD_IO，2=PADMUX 相关网络，3=GND。
- Flash 0x0 可读到有效程序字：20001197 80018193 20020117 ff810113。
- i2c_diag 默认 UART 为 PAD14/PAD15、115200；banner 在 main() 很早输出。

### 三种运行方法及结果
1. tinyriscv_10k.cfg（末尾含 halt）+ JTAG：JTAG 可识别核心，但配置主动暂停 CPU；按 SW1 后出现 dmstatus=0/authenticated 提示，串口无 banner。该方法不能用于观察运行中 UART。
2. tinyriscv_run.cfg（无 halt）+ JTAG：JTAG 可识别核心，但按 SW1 后仍出现 dmstatus=0，串口无 banner。说明问题不能只归因于 cfg 末尾的 halt。
3. 只接 Type-C、拔掉 DAPLink、只开 COM5：仍无 banner。说明 OpenOCD/JTAG 干扰已排除，问题集中在固件是否真正启动、启动模式/复位，或 UART 物理链路。

### 当前禁止事项
- 不再运行 flash_chip_100k.bat，不执行任何全片擦除或 Flash 写入。
- 不再把 H12/H13 同接口两脚短接。

## 2026-09-27 串口无输出与跳线排查最终状态

### 已确认
- `i2c_diag.bin` 的 Flash 内容正常。只读读回 `0x00000068` 得到：`fd010113 02112623 02812423 02912223 03212023 01312e23 01412c23 01512a23`，与当前构建产物中 `main()` 入口一致。
- 因此当前问题不是 Flash 被擦空，也不是 `i2c_diag.bin` 缺失。
- D:\BaiduNetdiskDownload\STM32入门教程资料\工具软件\串口助手\串口助手 V1.1.exe 可以用于本板 CH340C；它是通用 UART 工具，不是 STM32 专用。设置应为 COM5、115200、8-N-1，接收/发送文本模式。
- CH340 驱动已安装且 COM5 可打开；串口助手、Python serialmon 均能打开 COM5，但没有 banner。
- `tinyriscv_10k.cfg` 会 `halt`，不能用于观察正常启动；`tinyriscv_run.cfg` 可识别 RISC-V TAP，但 Debug Module 反复报自定义 `dmstatus=0x0` authentication 错误。
- `resume -> halt -> reg pc` 曾读到 `PC=0x00000000`；由于该自定义 Debug Module 的 resume/halt/step 不可靠，这不能单独证明 Flash 代码没有执行。

### 跳线/连接尝试
- H8：先试 2–3，后改试 1–2；均没有串口 banner。
- H10：先试 1–2，后改试 2–3；均没有串口 banner。H10=2–3 时 JTAG 会出现 DTM version 14/无效 DTM，这是因为 TDI 不再接 PAD0，不代表 Flash 损坏。
- OLED 已拔除；Type-C 单独供电时仍无输出；DAPLink 拔除后仍无输出。
- H12/H13 资料中的正确 UART 交叉关系：H12-1(CH340 TXD)→H13-2(CY63300 UART0_RX)，H12-2(CH340 RXD)→H13-1(CY63300 UART0_TX)。不要把同一排针的两个脚短接。

### 当前结论
- 已排除：Flash 空白、OLED 负载、单纯 JTAG 速度问题、串口助手型号问题。
- 尚未排除：H8/H10 的正常运行启动档位、UART0 PAD14/PAD15 到 CH340C 的实际物理通路、芯片是否从复位后真正执行到 `uart_init()`。
- 设计资料只说明正常运行保持 PADMUX/PAD0/TDI/NET6 的默认上下拉，没有明确给出 H8/H10 的“运行档位”表；后续不要把跳线位置当成已证实事实。
- 后续恢复工作时，先按“只读验证/物理连接确认”继续，不要运行 `flash_chip_100k.bat`，不要执行任何全片擦除或未经确认的 Flash 写入。
