# V8.6F OLED 单命令阶段结果

日期：2026-11-05（Asia/Shanghai）  
阶段：`BBX_V86F_OLED_DISPLAY_OFF_01`  
结果：**BLOCKED_JTAG_INIT**

## 执行摘要

用户因示波器探头可能碰到电脑、担心短路而明确不接示波器，要求直接发送。故本阶段不要求示波器捕获，只能用 JTAG 可读的控制器状态判断事务推进；即使成功，也不能声称已取得物理波形证据。

本阶段尝试发送 SSD1306 最短命令帧：地址 `0x3C`，TX FIFO 依次发送控制字 `0x00` 与显示关闭命令 `0xAE`，最后至多发一次 STOP。发送前检查未通过：OpenOCD 初始化时 JTAG scan chain 返回全零，IR capture 为 0，`dtmcontrol=0`。脚本在目标 MMIO 写入前停止。

- OpenOCD 版本横幅出现，DAPLink 序列号识别正确：`07000001006700343500000a4e57354aa5a5a5a597969908`
- JTAG IDCODE：**未读到**；日志报告 scan chain 全零（预期 `0x1E200A6F`）
- CPU halt / DMSTATUS / SBCS：**未能有效核验**
- 目标 MMIO 写：**0 次**
- OLED TX FIFO 数据：**未写入**
- STOP 请求：**0 次**
- OLED 屏幕状态：本次没有改变；没有证据表明收到任何 I²C 帧

## 保留的原始证据

运行目录：`runs/BBX_V86F_OLED_DISPLAY_OFF_01_20261105_190724_699154/`  
marker：`markers/BBX_V86F_OLED_DISPLAY_OFF_01.attempted.json`（已消费，保留）

| 文件 | SHA256 |
|---|---|
| 实际 argv、cwd、探针快照与脚本哈希 `command.json` | `B5406C223B1C93DCB0C826603BB5FCC99EC11B105D9BA7DEB8B0396379A9E1C6` |
| 合并 OpenOCD 原始日志 `openocd.combined.log` | `82C53F1523EB5BF2AA3DFD00FC2DA9C4B48FE62D84E92EA7D90A3C74E6394832` |
| 判定 `result.json` | `9C3D5E236B3EE2E13FC2362DBF1DFE61DE79CA52ADD08A01E34380C047C13DAA` |
| marker | `BE0A74A218A1A832F1609A768F708D8328C41C1DBC69A268A499450CE8E06A82` |
| 执行入口 `run_bbx_v86f_oled_command_once.py` | `E239888408E634DE52BEB37F52F281C53AA8DAD79C2E63C81141EC2665EBBD3D` |
| 执行 Tcl `03_experiments/bbx_v86f_oled_command.tcl` | `B4AA3DC7728644BDE8D8080C68EEAB7ED71C93FDAD90A508C4A434CD29348B4B` |

主机检查发现没有 OpenOCD/GDB 调试进程，监听端口检查为空。OpenOCD 本身进程退出码为 0，但包装器根据缺少目标连接与写入、结果状态 `FAIL_OR_UNKNOWN`，以失败退出；不得把 OpenOCD 的退出码 0 误当作测试通过。

## 原始错误要点

```text
Error: JTAG scan chain interrogation failed: all zeroes
Error: riscv.cpu: IR capture error; saw 0x00 not 0x01
Error: dtmcontrol is 0. Check JTAG connectivity/board power.
V86F_ERROR=V86F_JTAG_INIT_ERROR
V86F_RESULT=FAIL_OR_UNKNOWN TARGET_WRITE_COUNT=0 STOP_SENT=0
```

Tcl 在捕获初始化失败后仍尝试了最终只读 SBCS/DMSTATUS 查询；OpenOCD 回报 `dmi_read is not implemented for this target`。这些不是目标 MMIO 写入，但说明后续脚本应在 JTAG 初始化失败时跳过所有收尾 DMI 读取。该阶段没有重试。

## 解释与停止点

这是 **JTAG/调试连接在传输前失败**，不能解释成 OLED NACK、I²C FIFO 故障或 OLED 损坏。V8.6E 在本次运行前曾成功配置 `PERI_CLKEN=0x21`、GPIOB Pad8/9、`ADDR=0x3C` 和 `MODULE_CTRL=0x0F`；V8.6F 无法建立新 JTAG 会话，因此这些值本次均未复核。也不能据此认定它们现在仍保持原样。

由于阶段 marker 已创建，本阶段不可复用。未自动重新运行 OpenOCD、复位、改线、断电或发送第二次事务。下一步应先由用户在不碰电脑主板的前提下确认 DAPLink 与目标板供电/接触状态；待连接稳定后，另建新阶段，先进行只读 JTAG/IDCODE/DMSTATUS/SBCS 预检。预检通过后再决定是否进行 OLED 命令帧。若新阶段发送帧成功，仍需后续通过可靠测量或 OLED 可见响应确认真实总线行为；本阶段没有产生该证据。
