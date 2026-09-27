# CY63300 RISC-V I²C 测试接线与流程

日期：2026-09-27

## 当前状态

RISC-V JTAG 已经跑通。OpenOCD 已识别：

```text
JTAG tap: riscv.cpu tap/device found: 0x1e200a6f
Examined RISC-V core; found 1 harts
hart 0: XLEN=32
```

因此后续 I²C 测试使用 RISC-V 裸机工程和 `riscv-none-embed-gcc`，不能使用 Keil5 的 ARM 工程。

## 工具位置

| 工具 | 路径 |
|---|---|
| RISC-V GCC 8.3 | `D:\project\tools\xpack-riscv-none-embed-gcc-8.3.0-2.3\bin\` |
| OpenOCD（当前已验证） | `D:\project\tools\tinyriscv-master\tools\openocd\openocd.exe` |
| OpenOCD 配置 | `D:\project\tools\tinyriscv-master\tools\openocd\tinyriscv.cfg` |
| GNU Make | `C:\Users\24796\AppData\Local\Microsoft\WinGet\Packages\ezwinports.make_Microsoft.Winget.Source_8wekyb3d8bbwe\bin\make.exe` |

## 已有 I²C 诊断程序

实际文件位于：

`D:\project\新建文件夹\test\i2c_diag\`

其中已有 `i2c_diag.c`、`i2c_diag.elf`、`i2c_diag.bin`、`i2c_diag_pin1.bin`、`flash.bat`、`diag_run.py` 和 `serialmon.py`。

该程序通过串口菜单执行：

| 按键 | 功能 |
|---|---|
| `d` | 读取 SDA/SCL 线电平 |
| `a` | 1 Hz 慢速翻转，确认排针到芯片的连线 |
| `b` | GPIO 模拟 I²C，全地址扫描 `0x08` 至 `0x77` |
| `c` | 使用硬件 I²C 控制器扫描 |
| `r` | 依次执行完整流程 |

串口参数：115200-8-N-1，接口是板载 CH340。

## 测试板 I²C 接口

原理图和 PCB 网络确认 H2 为 2×2 I²C 接口：

| H2 | 网络 |
|---:|---|
| 1 | VDD_IO |
| 2 | GND |
| 3 | SCL |
| 4 | SDA |

板上 R3、R4 已将 SCL、SDA 上拉到 VDD_IO。H4 也引出了：H4-8=SCL，H4-9=SDA。

## 关键跳线关系

H10 是 1×3 跳线：

| H10 | 网络 |
|---:|---|
| 1 | TDI |
| 2 | PAD0 |
| 3 | NET6 |

RISC-V 复用表中 Pad0 的功能 0 是 `jtag_tdi`，功能 1 是 `I2C_SCL`；Pad1 的功能 1 是 `I2C_SDA`。Pad8/Pad9 也提供 I²C 复用，且当前测试板 H4 的 SCL/SDA 网络对应诊断程序默认使用的 Pad8/Pad9。

所以：

1. 首次使用默认的 `i2c_diag.bin`（SCL=Pad8、SDA=Pad9）时，H10-1/2 可以保持短接，JTAG 仍可用。
2. 只有改用 `i2c_diag_pin1.bin`（SCL=Pad0、SDA=Pad1）时，才需要断电后移除 H10-1/2；否则外部 TDI 会和 Pad0/SCL 相连。
3. H10-3（NET6）不接。
4. H8 是 PADMUX 模式跳线，暂不随意改变；先用默认 Pad8/Pad9 固件完成第一次 I²C 扫描。

## 推荐测试流程

1. 板子 USB-C 供电，DAPLink 保持 U5 JTAG 接线。运行 flash.bat 前先停止手动启动的 OpenOCD。
2. H10-1/2 保持短接，使用默认的 `i2c_diag.bin`（Pad8/Pad9）烧录到地址 `0x0`。
3. 烧录完成后重新复位运行；使用默认 Pad8/Pad9 时不需要拆 H10。
4. 重新上电，H2 接外部 I²C 从设备：SCL→H2-3，SDA→H2-4，GND→H2-2，设备电源→H2-1/VDD_IO。
5. 用 CH340 串口打开 115200-8-N-1，按 `r`；或运行：

```powershell
cd "D:\project\新建文件夹\test\i2c_diag"
python .\diag_run.py
```

6. 先看 `d`，再看 `b` 软件位扫，最后看 `c` 硬件控制器扫描。
7. 如果没有外部从设备，扫描得到无 ACK 是正常的；至少应先确认 `d` 的 SDA/SCL 空闲电平为高。

## 寄存器依据

I²C 外设基地址为 `0x40002800`。设计文档 4.19 节给出的关键偏移：

```text
MODULE_CTRL  0x00
TX/RX FIFO   0x08
FIFO_STA     0x0C
CLK_DIV0     0x10
CLK_DIV1     0x14
I2C_MODE     0x20
I2C_ADDR     0x24
I2CM_CTRL    0x28
I2C_STATE    0x3C
```


## 2026-09-27 烧录实测

- 使用 flash.bat 在 1000 kHz 烧录 7204 字节，verify_image 在 0x0C48 或 0x184E 报单字节不一致。
- 使用 flash_100k.bat 将 JTAG 频率降到 100 kHz，仍在 0x184E 报同样的不一致。
- 使用 flash_chip_100k.bat（FLS_CTL 的 rwe_sel=3，整片擦除）后，OpenOCD 输出 'verified 7204 bytes'，脚本输出 '[2/3] Flash OK. verify passed.'。
- 因为执行了整片擦除，原 Flash 程序已被替换为 i2c_diag.bin。此结果仅证明烧录及读回校验通过，尚未证明 I2C 读写通过。
- 后续：断电接回四针 OLED 到 H2，重新上电，CH340 串口 115200-8-N-1，先执行 d 再执行 b，记录扫描地址；预计常见 OLED 地址为 0x3C 或 0x3D。


## 2026-09-27 烧录后排障进展

- OLED 接回后，COM5（CH340，VID:PID=1A86:7523）能打开，但按 SW1、输入 d、板子重新上电均无诊断串口输出；OLED 不亮本身是预期现象，因为 i2c_diag 只扫地址，没有初始化显示屏。
- OLED 断电拔除后，OpenOCD 在 1000 kHz 和 100 kHz 均报 JTAG scan chain all zeroes。
- 另以 100 kHz、connect_assert_srst（连接时保持复位）扫描，仍报 all zeroes。由此暂不支持诊断固件运行后关闭 JTAG 的解释；优先排查目标板实际供电、U5 的 TDO/GND/Vref 接触、H8/H10 启动跳线。
- 未进一步擦写 Flash；上一次整片擦除后的 7204 字节 verify_image 已通过，但尚未证实启动和 I2C 通信。

## 2026-09-27 重要纠正：全片擦除风险与因果关系

- 设计文档 3.3.1 将 Flash 0x00000000–0x0000FFFF 标作 system memory，将 0x00010000–0x0003FFFF 标作 user memory；4.5.2.4 的全片擦除会触发 Chip 擦除。此前建议将 flash 脚本从 rwe_sel=2 改成 3 不够审慎。
- flash_chip_100k.bat 只在 0x0 写入并校验了 7204 字节，不能证明原先 64 KB system memory 的其余内容仍在。没有擦除前完整读回备份，不能确认具体丢失内容。
- JTAG all zeroes 在这次整片擦除之前也出现过，故不能断定整片擦除导致失联；同样不能将本次失联简单断定为接触不良。OLED 已拔掉、100 kHz 与连接时保持复位均失败。
- 在取得芯片版本对应的官方启动、Flash 布局和恢复资料前，暂停进一步整片擦除、烧录和不明映像恢复。目录中 fw_cs_master.hex 的开头是 ARM 向量表形式，不应直接作为 RISC-V 板恢复固件。

## 2026-09-27 对启动地址风险的再核对

- 本地《测试技术报告》RISC-V 工程的第 5 章明确说明 _start/Flash 起始地址为 0x00000000，原链接脚本也以 0x0 为 ORIGIN。因此不能仅凭另一份偏向 CM0 版本的数字设计文档将 0x0 称为 system memory，就断言本次 0x0 写入导致芯片无法启动。
- 整片擦除是否删去了该实物板需要的其他内容仍未证实；当前没有全片擦除前的完整 Flash 备份。
- JTAG all zeroes 在本次擦写前已多次出现，且曾在接线调整后恢复。下一步只读、单变量排查 TDO 返回线和目标板电源，不再重复擦写或假定固件已损坏。

## 2026-09-27 全片擦除与 JTAG 失联的区分

- 芯片设计文档 4.5.2.4 称在 main Flash 地址触发 chip erase；若要 NVR+Chip 一起擦除，需在 NVR 地址触发。本次脚本触发地址为 0x00000000，因此现有证据不能说它擦除了 NVR。
- 文档第 5 章称 jtag_disable 需要 NVR1 特定值 0x12345678 且 NVR2 保护等级大于 3 才会关闭 JTAG。本次脚本写入 0x12345678 的地址是 main Flash 0x0，并非 NVR1。两者数值相同不代表操作目标相同。
- 芯片在擦除前已出现过 all-zero JTAG 扫描；本地 RISC-V 测试报告又明确把 _start 链接到 0x0。由此不能将当前 JTAG 失联直接归因于 chip erase。全片擦除可能影响启动内容并解释 UART 无输出，但仍缺乏 Flash 事前备份和目标供电、复位实测。
- 下一步暂停写操作；测 U5-7 对 GND 的目标电压及 U5-8 复位电平。两项正常而 JTAG 仍全零时，向原测试者/芯片设计人员确认这块 RISC-V 实物板的启动映像、NVR 配置和恢复接口。
