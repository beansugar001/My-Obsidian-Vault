# V8.6 I²C 卡住状态恢复结果

日期：2026-11-05（Asia/Shanghai）  
阶段：`BBX_V86_I2C_STUCK_FIFO_RECOVERY_01`  
结论：**FAIL_OR_UNKNOWN；I²C 复位断言成功，但解除复位未生效。停止 OLED 测试。**

## 本阶段目标与风险

V8.5 后的实物状态为 TX FIFO 有 2 字节、I²C master `WORK=1`、`MCTR.STOP=1`。按 CY63300 A0 数字设计说明第 23 页，`PERI_RST` 偏移 `0x10` 的 bit5 是 `I2c_sofrst`，写 1 使能软复位，写 0 禁止软复位。本阶段只针对这个位尝试一次 `0→1→0`，以清除挂起的事务并解除复位；不访问 OLED 数据 FIFO，不改 Flash/NVR。

## 实际前置状态

新 OpenOCD 会话确认探针序列号 `07000001006700343500000a4e57354aa5a5a5a597969908`、唯一 TAP `riscv.cpu`、IDCODE `0x1E200A6F`。CPU 初始 running，脚本只请求一次 `halt 2000`，随后 `curstate=halted`、DMSTATUS=`0x00430382`、SBCS=`0x20040404`。

写前目标寄存器读回：

| 寄存器 | 地址 | 写前读值 |
|---|---:|---:|
| PERI_CLKEN | `0x4002180C` | `0x21` |
| PERI_RST | `0x40021810` | `0x00` |
| MODULE_CTRL | `0x40002800` | `0x0F` |
| FIFO_STA | `0x4000280C` | `0x204` |
| I2CM_CTRL | `0x40002828` | `0x02` |
| I2C_STA | `0x4000283C` | `0x01` |
| RAW_INTR_STA | `0x40002858` | `0x00` |
| GPIOB_IDR | `0x40000150` | `0x2C`，Pad8/9 采样高 |

前置状态与 V8.5C 独立快照吻合，故本阶段执行了复位恢复动作。

## 实际写入与结果

本阶段目标 MMIO 写入共 2 次，且均仅针对 `PERI_RST=0x40021810`：

1. `0x40021810 <- 0x00000020`：写后独立读回 `0x20`，断言有效。
2. `0x40021810 <- 0x00000000`：OpenOCD/SBA 命令无报告错误，但写后两次独立读回均为 `0x20`，解除复位**未生效**。

后验读回：`PERI_CLKEN=0x21`、`PERI_RST=0x20`、`MODULE_CTRL=0x00`、`FIFO_STA=0x00`、`I2CM_CTRL=0x00`、`I2C_STA=0x00`、`RAW_INTR_STA=0x00`、`GPIOB_IDR=0x2C`。`SBCS=0x20040404`、DMSTATUS=`0x00430382`。I²C 寄存器读值是在复位仍断言时观察到的，不作为正常配置值解释。

判定：复位断言确实到达并影响了 I²C 模块；SBA 的干净状态和 DMI 命令返回不能证明解除写已提交。**此时不能重新初始化或发 OLED 事务。** 本阶段没有 OLED START/ACK/STOP 证据，也没有显示 `Hello`。

## 与历史 V4.9 的关键对照

检查发现 V4.9 已做过相同的 `PERI_RST=0x20` 断言后再写 `0x00` 解除：其 `release_reset` 原始日志也显示写命令返回、SBCS 干净，但 `PERI_RST` 两次仍读 `0x20`，最后状态为 `RESET_RELEASE_NOT_VERIFIED_STOP`。V4.9 文档明确要求此情形停止，不要盲目重复断言、断电或改跳帽。

所以 V8.6 的现象不是本次独有的等待时间不足；同一类“零值解除写对寄存器读回不可见”至少复现两次。当前证据更支持**PERI_RST 的 0 写提交路径或流片寄存器语义异常/未明**，尚不足以区分 SBA/RIB 写零问题和 PERI_RST 硅实现问题。不得继续用相同路径自动重试。

## 阶段原始证据

- 完整日志：[openocd.combined.log](runs/BBX_V86_I2C_STUCK_FIFO_RECOVERY_01_20261105_160413_452922/openocd.combined.log)，SHA-256 `E42338D0F5C6C95581505B715DD8DDB4895C66EB996DFBB86CFC730D177706B7`
- 命令和输入哈希：[command.json](runs/BBX_V86_I2C_STUCK_FIFO_RECOVERY_01_20261105_160413_452922/command.json)
- 机器可读结果：[result.json](runs/BBX_V86_I2C_STUCK_FIFO_RECOVERY_01_20261105_160413_452922/result.json)
- 永久阶段标记：[BBX_V86_I2C_STUCK_FIFO_RECOVERY_01.attempted.json](markers/BBX_V86_I2C_STUCK_FIFO_RECOVERY_01.attempted.json)
- 实际脚本：[bbx_v86_i2c_recover.tcl](03_experiments/bbx_v86_i2c_recover.tcl)
- 运行器：[run_bbx_v86_i2c_recover_once.py](run_bbx_v86_i2c_recover_once.py)

## 当前停止点与到 Hello 的下一步

当前最新证据是 `PERI_RST[5]=1`，I²C 处于复位；本阶段已消费，不重复运行。因为历史 V4.9 已记录同样的释放失败，下一步先做离线根因审查，并与芯片供应方核实该版 `PERI_RST` 的写入/释放语义和可用恢复方法。若需要让目标整板掉电再上电以清除易失复位状态，需要用户实际执行物理断电；本环境无法替用户拔插电源。重新上电后先开一个全新的只读阶段确认 `PERI_RST=0`、I²C 复位默认值、FIFO 空且 master idle，再按 ARM 初始化顺序恢复 I²C，之后才能分阶段发送 OLED 初始化和 `Hello` 字模。

任何恢复方式未核实前，不写 `MODULE_CTRL`、FIFO 或 OLED 命令，不追加软复位，不做 Flash/NVR 操作。
