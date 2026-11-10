# V117B：重新插拔后的控制器状态

## 结论

本次取得了有区分度的新证据，但还没有让 OLED 通信成功。重新插拔后，CPU 一开始是 running；halt 后只读得到：

```text
IDCODE       = 0x1E200A6F
DMSTATUS     = 0x00430382
SBCS         = 0x20040404
PERI_CLKEN   = 0x00000021
PERI_RST     = 0x00000000
MODULE_CTRL  = 0x0000000F
FIFO_STA     = 0x00000204  (TX_NUM=2)
I2C_STA      = 0x00000001  (WORK=1, DATA=0)
RAW_INTR_STA = 0x00000000
MCTR         = 0x00000002  (STOP=1)
```

这不是干净的上电基线。状态与 V116B 诊断程序配置的 CLKEN、MODULE_CTRL、ADDR、FIFO 及 STOP 请求高度吻合。V116B 已被写入 Flash 地址 `0x0..0x3DB`，所以如果这次“重新插拔”确实让芯片复位，主 Flash 中的诊断程序会再次从 0 地址启动并重现这组状态；另一种可能是目标电源没有真正掉到底，原控制器状态仍保持。**当前只能确认重新插拔后没有回到 idle，不能仅凭这次快照区分这两种情形。**

这是本轮最重要的进展：此前把“重新插拔”当作控制器状态已清零的前提不成立；而测试固件写进主 Flash 后会在启动地址重新执行，可能每次上电都再次填充 FIFO。后续不得再把插拔后的相同状态当作 FIFO 未被复位的芯片缺陷证据。

## 执行范围

- 阶段：`BBX_V117B_POST_REPLUG_READONLY_20261110_01`
- DAPLink：序列号 `07000001006700343500000a4e57354aa5a5a5a597969908`
- 只识别到唯一 TAP；IDCODE 正确。
- CPU 初始 running；发送一次 `halt 2000` 请求并确认 halted。
- MMIO 写入次数 0；未读取/写入 Flash/NVR；未复位或 resume。
- 主机进程枚举需要提升权限才能完成；在提升权限下未发现 OpenOCD/J-Link/GDB 等进程，TCP 3333/4444/6666 无监听，之后才执行了本次只读会话。
- 当前 CPU 经 halt 停止；不要假设关闭 OpenOCD 后仍保持 halted。

原始日志：

`C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX\runs_local_v116\BBX_V117B_POST_REPLUG_READONLY_20261110_01_20261110_135146\openocd.combined.log`

SHA256：`EC2AFD010C25D13988D74920812C71A11758B0282EF5F5ABFC829C3043766D3F`

## 根因判断更新

| 假设 | 本轮证据 | 结论 |
|---|---|---|
| 重新插拔清除了 FIFO | FIFO 仍有 2 字、WORK=1、STOP=1 | 不成立；插拔后未观察到 idle |
| V116B CPU store 进入 FIFO | V116B 写后计数为 1、再为 2；V117B 复核为 2 | 支持 store 被 FIFO 状态计数接受 |
| I²C 引擎完成线上发送 | DATA=0、FIFO=2、RAW=0；没有示波器波形 | 未证明，当前仍未推进 |
| 每次开机由 Flash 固件重现状态 | V116B 固件位于 Flash，状态与其设置一致 | 高度可疑，但尚未确认这次是否真正掉电或读到启动邮箱标记 |

## 下一步

1. 先停止再次拔插/重复发送；当前测试程序在主 Flash，任何真正复位都可能重新运行。
2. 只读核实当前 PC/邮箱 `MBOX` 与 stage 是否是 `0x600D`，用于确认 V116B 是否在本次启动重新完成。
3. 先离线设计防自动重放方案，再考虑任何 Flash 修改。已有 256 KiB、全 `0xFF` 的烧录前备份；V116B 当前只改动了前 988 字节，但擦除扇区/改写复位入口都需单独核对擦写粒度、1→0 限制和恢复流程，不能盲目处理。
4. 不要立即运行已编译的 V117 SRAM 程序：先证明 CPU 已从 Flash 的重放路径脱离，并评估如何避免程序再次开机自动运行；否则无法把下一轮结果与本轮状态分开。

V117B 只读 Tcl SHA256：`2DB0BAD68805173BF162B8CCEC02D65F8DB6D4EFA9FAFB3163E8F9E0275271E4`。
