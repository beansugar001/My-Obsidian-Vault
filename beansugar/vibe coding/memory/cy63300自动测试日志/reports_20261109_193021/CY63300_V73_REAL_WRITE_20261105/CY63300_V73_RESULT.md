# CY63300 V7.3 真实芯片实验结果

日期：2026-11-05（Asia/Shanghai）  
阶段：`V73_REAL_WRITE_01`  
最终状态：**AHB 时钟写入未确认生效；按失败停止规则未进入 CLK_DIV0 写入。**

## 执行结果

| 项目 | 实测结果 |
|---|---|
| 主机进程检查 | `HOST_READY_CANDIDATE`；未发现已知调试客户端。Quartus `jtagserver.exe` PID 16884/TCP 1309 仅作信息记录 |
| DAPLink 序列号 | `07000001006700343500000a4e57354aa5a5a5a597969908` |
| OpenOCD/JTAG | `0.10.0+dev-00914-g4cb81306a-dirty`，100 kHz |
| TAP/IDCODE | 唯一 `riscv.cpu`，`0x1E200A6F`，PASS |
| halt | 起始 `running`；发送 `halt 2000` **一次**；之后 `curstate=halted`，PASS |
| DMSTATUS | `0x00430382`；`allhalted/anyhalted` 均置位，PASS |
| SBCS 写前 | `0x20040404`，busy/error 清零，PASS |
| PERI_RST 写前 | `0x00000000`，PASS |
| PERI_CLKEN 写前 | `0x00000000` |
| PERI_CLKEN 目标写 | `0x4002180C <- 0x00000020` **尝试一次** |
| SBA 写事务状态 | 写地址及数据后观察到 `SBCS=0x20040404`，busy/error 清零 |
| PERI_CLKEN 独立读回 | `0x00000000`，与目标 `0x20` 不符；写入未获提交确认 |
| CLK_DIV0 | 未读取，未写入；第二项条件实验未开始 |
| 目标 MMIO 写入总数 | **1 次**，只有 `0x4002180C <- 0x20` |
| 复位/resume/恢复/重试/断电 | 均为 0 次 |

## 结果解释

本次证明 OpenOCD 能连接正确 TAP、发送单次 halt 请求并确认 hart halted；也读取到预期 DMSTATUS、SBCS 与写前时钟/复位值。`PERI_CLKEN` 的目标写事务命令发出后，SBA 很快报告 idle 且没有 busy/error，但新发起的 SBA 读事务仍读到 0。**因此仅凭 SBCS 干净状态不能说写入成功；这次 AHB SYSCTRL 写未被独立读回确认。**

按授权，实验在此停止，未访问 I²C MODULE_CTRL 或 CLK_DIV0 写路径。现有证据优先要求调查 **Debug Module/SBA 写提交、DM 到内部互联路径，以及 SYSCTRL AHB 写接受/寄存器写使能**。目前没有 AHB HREADY/HRESP 或 SBA 下游 grant/commit 波形，不能精确定位失败层，也不能判定芯片损坏。

OpenOCD 进程退出码为 0，但语义状态是 `FAIL_OR_UNKNOWN`、没有 `V73_COMPLETE`；不能把进程退出码当作硬件 PASS。无自动重试或恢复。hart 在会话结束前最后确认是 halted；关闭 OpenOCD 后没有再次查询，因此不把会话结束后的即时状态冒充为新读数。

## 原始日志与复核信息

完整启动 argv 和工作目录见 `command.json`；真实 OpenOCD 文本在 `openocd.stderr.log`，`openocd.stdout.log` 为空，`openocd.combined.log` 是便于阅读的合并副本。关键原始行：

```text
Info : clock speed 100 kHz
Info : JTAG tap: riscv.cpu tap/device found: 0x1e200a6f
V73_CPU_STATE_BEFORE_HALT=running
V73_HALT_REQUEST_ATTEMPT=1 TIMEOUT_MS=2000
V73_CPU_STATE_AFTER_HALT=halted
V73_DMSTATUS 0x00430382
V73_SBCS_INITIAL 0x20040404
V73_INITIAL_PERI_RST 0x00000000
V73_INITIAL_PERI_CLKEN 0x00000000
V73_TARGET_WRITE_ATTEMPT 1 0x4002180C 0x00000020
V73_SBCS_POLL WRITE_DATA 000 0x20040404
V73_TARGET_R PERI_CLKEN_AFTER_WRITE 0x4002180C 0x00000000
V73_PERI_CLKEN_AFTER 0x00000000
V73_STATUS=FAIL_OR_UNKNOWN
V73_STOP_REASON=CLOCK_ENABLE_READBACK_MISMATCH_STOP
V73_HALT_ATTEMPTS=1
V73_TARGET_MMIO_WRITE_ATTEMPTS=1
shutdown command invoked
```

| 文件 | SHA256 |
|---|---|
| `openocd.stdout.log` | `E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855` |
| `openocd.stderr.log` | `04B9779B774441812A830BE427F9FB0379F55A469F99808478DF1BD7DCB76343` |
| `openocd.combined.log` | `2F380C9F8BADB479C881D63144E7217A9ADA0C8755CBEECA1EBF32E04DCDD8A` |
| `result.json` | `D5603287CEA03635B6D5ADBE29310F0E6B8AB828CEA10E2CDCB9E2A51E7BBC74` |
| `command.json` | `86FBE3B80C3B83FE39CE649B90E9A98C413ED61BB8E9B1E440AE3FA9190F8029` |
| `V73_REAL_WRITE_01.attempted.json` | `3A5B48B4B9E221D8ECF6CAB8E121FAB54F1111D45196350B708055E49610689D` |
| `v73_real_write.tcl` | `8FDE615A09B86A00D5CCF27EDF8EA1585310D6D2AABBDC6CE3C9DD8AA277B5D3` |
| `v73_100k_no_servers.cfg` | `6770C370510C16FE1CF964ABF2F9D702743F5DF75F61890179F42415836D0B9B` |

阶段 marker 已创建并保留，禁止删除或复用。**没有任何授权或脚本自动执行 CLK_DIV0、MODULE_CTRL、FIFO、I2C_EN、复位、resume、Flash/NVR、恢复写或断电操作。**

## 下一步建议

先审查本轮原始 SBA 命令序列和日志，并向芯片/设计资料获取真实 SBA 下游提交、AHB HREADY/HRESP 与 SYSCTRL 写使能可观察证据。不要直接把测试切到 CLK_DIV0：V7.3 的规则要求 AHB 写读回通过后才进入 I²C APB 实验。若要重做 SYSCTRL 写入，V7.3 阶段 marker 已消费，必须新建阶段、重新审查事务和取得新的明确授权；本报告不自动授权重试。
