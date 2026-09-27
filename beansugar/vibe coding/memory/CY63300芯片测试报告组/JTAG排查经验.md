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
