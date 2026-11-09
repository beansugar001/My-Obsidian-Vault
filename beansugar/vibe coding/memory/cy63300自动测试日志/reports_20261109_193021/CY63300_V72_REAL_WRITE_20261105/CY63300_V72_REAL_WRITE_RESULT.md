# CY63300 V7.2 真实写入实验结果

日期：2026-11-05（Asia/Shanghai）  
阶段：`V72_REAL_WRITE_01`  
结论：**BLOCKED_BEFORE_WRITE；本轮目标 MMIO 写入 0 次。**

## 执行结果

| 检查项 | 实际结果 |
|---|---|
| 主机互斥检查 | `HOST_READY_CANDIDATE`；未发现已知调试客户端。Quartus `jtagserver.exe` PID 16884 / TCP 1309 为信息项，不构成单独冲突 |
| CMSIS-DAP 序列号 | `07000001006700343500000a4e57354aa5a5a5a597969908` |
| JTAG 速度 | 100 kHz |
| TAP / IDCODE | 唯一 `riscv.cpu`，`0x1E200A6F`，通过 |
| Hart 状态 | OpenOCD `targets` 输出为 **running**，不是 halted |
| DMSTATUS / SBCS | 未读取。脚本在 hart halted 门槛处停止，未继续触碰 SBA/目标寄存器 |
| PERI_CLKEN / PERI_RST | 未读取，因此没有写前/写后值 |
| MODULE_CTRL / CLK_DIV0 | 未读取，因此没有写前/写后值 |
| 目标 MMIO 写入 | **0 次**；没有执行两个候选写入中的任何一个 |
| OpenOCD 退出码 | 0，但不能作为通过；没有 `V72_COMPLETE`，语义结果为失败/未知，执行器据此返回非零 |

### 停止原因

实际目标状态输出明确为：`0* riscv.cpu riscv little riscv.cpu running`。写入前置条件要求 CPU halted，因此即使忽略脚本问题也必须停止。随后检查脚本还遇到 Tcl 正则兼容错误：`couldn't compile regular expression pattern: count follows nothing`（halted 状态匹配式中的内嵌模式标记不被此 OpenOCD Tcl 正则实现接受）。脚本没有执行 `halt`，没有尝试修复后重连，也没有继续读取 SBCS 或外围寄存器。该问题同时说明：本次停止链路的原始脚本判定没有完整解析 halted 状态；报告依据直接记录的 `targets` 行确认 hart 正在运行。

## 原始 OpenOCD 证据

启动命令参数（完整 argv 和 cwd 见 `command.json`）：

```text
D:\project\tools\tinyriscv-master\tools\openocd\openocd.exe
  -f C:/Users/24796/Documents/组/CY63300_V72_REAL_WRITE_20261105/v72_nohalt_100k.cfg
  -c "source C:/Users/24796/Documents/组/CY63300_V72_REAL_WRITE_20261105/v72_real_write.tcl"
```

工作目录：`D:\project\tools\tinyriscv-master\tools\openocd`

日志关键行：

```text
Info : clock speed 100 kHz
Info : JTAG tap: riscv.cpu tap/device found: 0x1e200a6f
Info : Examined RISC-V core; found 1 harts
Info :  hart 0: XLEN=32, misa=0xcc80680a
0* riscv.cpu          riscv      little riscv.cpu          running
V72_STATUS=FAIL_OR_UNKNOWN
V72_STOP_REASON=couldn't compile regular expression pattern: count follows nothing
V72_TARGET_MMIO_WRITE_ATTEMPTS=0
shutdown command invoked
```

`openocd.stdout.log` 为空；OpenOCD 原始文本在 `openocd.stderr.log`，合并副本在 `openocd.combined.log`。命令执行器退出码虽为 0，但由于没有完成标记且状态为 `FAIL_OR_UNKNOWN`，整体不得判 PASS。

## 文件与哈希

| 文件 | SHA256 |
|---|---|
| `openocd.stdout.log` | `E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855` |
| `openocd.stderr.log` | `43BA36EE47747C9B86CBC8A7A344E32C5316D5A2D3D400E83DAE0E472F3358E5` |
| `openocd.combined.log` | `412DCAC99045657B6098BFE37B64639E1235E14BB744598F02EA2C19AF6377C5` |
| `result.json` | `CACA462EEB41D6A61F8003B9F2682B3E0ABA41E17C32008A9871DF1F50154B50` |
| `command.json` | `F9BCE19FF60C34011DFA371E3EC3366D9A8A850B3759D3D7D2459DF9DD30963F` |
| `V72_REAL_WRITE_01.attempted.json` | `ED07876497B4D5864EAFF38F089720AAD78B02A86088598C2E858A1742320DFE` |
| `v72_real_write.tcl` | `1A2832C33FFDD2AF8DED87F529A66A3B89B41E213B18659BE1DCC045014BE549` |
| `v72_nohalt_100k.cfg` | `DBCA0EC70C66804361D2D69520E2B0DC7F818293C004C88BF7E7985C3A062229` |
| `host_ready_before_v72.log` | `E32F99ABCA85C97A107724EE44A98440A9FEA5CEBE3B47993E149B56CFA472D9` |

阶段 marker 已创建并保留；本阶段不重试、不删除 marker、不自动 halt/reset/resume、不恢复或断电。由于写入未发生，情况 A/B/C 不能从本轮判别。

## 下一步

先由用户决定是否要另开阶段处理“hart 当前 running”这一前置状态，并修正 Tcl 对 `targets` 状态行的解析。当前写授权对应的一次性阶段 marker 已消费，不能修补原阶段后重跑；任何后续硬件操作需新阶段与明确授权。恢复到 halted 只能使用明确授权的操作，不能把 halt 隐含进配置。修正并获得授权后，再按原条件新建一次性执行阶段；写入前必须重新确认 CPU halted、SBCS idle/error-free、`PERI_RST=0` 和 `PERI_CLKEN` 的准确值。
