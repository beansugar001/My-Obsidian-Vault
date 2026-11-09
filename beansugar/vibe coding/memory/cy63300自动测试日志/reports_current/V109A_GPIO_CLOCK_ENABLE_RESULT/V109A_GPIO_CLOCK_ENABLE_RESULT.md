# V109A GPIO 时钟开启阶段执行结果

## 判定

**BLOCKED_BEFORE_TARGET_WRITE。** OpenOCD 找到正确 DAPLink 和唯一 CY63300 TAP，但 CPU 初态为 `running`。按本阶段的 fail-closed 规则，未发送 halt 请求；没有进入 MMIO 前置读取，也没有执行授权写入。目标 MMIO 写入次数为 0，GPIO 寄存器未读取。

## 实际证据

- 阶段：`BBX_V109A_GPIO_CLOCK_ENABLE_01`，marker 已创建并保留；不要重用本阶段。
- DAPLink：`07000001006700343500000a4e57354aa5a5a5a597969908`。
- 唯一 TAP：`riscv.cpu`，IDCODE=`0x1E200A6F`；misa=`0x4CC0680A`。
- `riscv.cpu curstate` 返回 `running`。脚本未调用 `halt`。
- 终止时 DMSTATUS=`0x00430C82`；SBCS=`0x20040404`，无 busy/error。
- host 检查未发现 OpenOCD/GDB 等相关进程或监听端口。Altera JTAG Server 仍为非冲突项，未停止。
- 目标 MMIO 写：0 次；目标 MMIO 读：0 次；PERI_CLKEN 写 `0x1` 未发出；GPIOB/I²C 寄存器未访问。
- OpenOCD 进程退出码 0、阶段 Tcl 有完整结束标记，但状态为 `FAIL_OR_UNKNOWN`，所以不把退出码 0 当作测试通过。

## 前置授权状态

用户此前对 `0x4002180C <- 0x00000001` 的一次写入授权**尚未被使用**，因为实际写入未发出。本阶段 marker 已消费；如继续，应创建新阶段/新 marker。若要在新阶段先对 CPU 发出一次 `halt 2000`，需要用户明确授权这项额外动作；得到授权后才可复用尚未执行的那一次 GPIO 时钟写入授权，并继续做独立读回。不得自动恢复、重试或写其他地址。

## 日志与哈希

- 运行目录：`D:\project\RISCV-63300\CY63300_I2C_BLACKBOX\runs\BBX_V109A_GPIO_CLOCK_ENABLE_01_20261109_204324_986014`
- 完整日志 SHA256：`6056493E78B3917B74B0174E890F67A3FF6DA709EEF35929A6489F6FE0CAC273`
- stderr SHA256：`F2A69D1BE053FA7372A41B56573264C84235839293E77B857CAF049AB5CDA3FE`
- result.json SHA256：`252325D73A6D9D9921E7D354C9436B0D35707AE32D332174E2F4E672E6725F1A`
- V109A Tcl SHA256：`163B9EB7591ACAD4CCA6B89EA16F125351A8E48ADEC8FC522D3DE2B26104E0D3`
- Runner SHA256：`081423878406EBD68A1BDAC84B013FE0647CECA523F6FB6017C1F8BE2991ECD5`

本阶段没有改变芯片外设状态。
