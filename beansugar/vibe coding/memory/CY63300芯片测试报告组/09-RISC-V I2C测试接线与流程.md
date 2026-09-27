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

