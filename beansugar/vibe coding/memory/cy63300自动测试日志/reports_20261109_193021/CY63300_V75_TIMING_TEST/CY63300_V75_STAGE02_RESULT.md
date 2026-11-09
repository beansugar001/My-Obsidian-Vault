# CY63300 V75_SYSCTRL_DELAY_02 执行结果

**阶段结果：BLOCKED；目标写入次数：0。**

启动前检查通过：`V75_SYSCTRL_DELAY_02` marker 不存在，且未发现其他 `openocd.exe` 进程。OpenOCD 成功连接到指定 DAPLink，IDCODE 正确；但本次新会话读到 CPU 状态为 `running`。V7.5 脚本要求 CPU 已 halted，且 V75_SYSCTRL_DELAY_02 授权不包含 halt，因此在写入前停止。

| 检查项 | 结果 |
|---|---|
| DAPLink 序列号 | `07000001006700343500000a4e57354aa5a5a5a597969908`，匹配 |
| JTAG IDCODE | `0x1E200A6F`，匹配 |
| CPU 状态 | `running`；停止条件触发 |
| DMSTATUS / SBCS | 未读；脚本在 CPU 状态检查后停止 |
| PERI_RST / PERI_CLKEN | 未读 |
| `0x4002180C <- 0x20` | 未执行；目标 MMIO 写计数 0 |
| reset / resume / 恢复 / 重试 | 未执行 |
| OpenOCD 返回码 | 0；但无 `V75_COMPLETE`，状态为 `FAIL_OR_UNKNOWN`，不得判为通过 |

前一个只读 halt 阶段记录了 CPU 从 running 转为 halted，但该 OpenOCD 会话关闭后，本次新连接又观察到 running。当前证据只能说明两个会话之间 CPU 状态恢复为 running；不能确定是 OpenOCD 断开时恢复、目标程序自行运行，还是其他外部因素。V75_SYSCTRL_DELAY_02 没有发出 halt 请求。

阶段 marker 已创建并保留：

`D:\project\RISCV-63300\CY63300_AUTO_TEST\markers\V75_SYSCTRL_DELAY_02.attempted.json`

原始日志目录：

`C:\Users\24796\Documents\组\CY63300_V75_TIMING_TEST\runs\V75_SYSCTRL_DELAY_02_20261105_112449_703021`

- `command.json` SHA-256：`16D5E1A52ED42DACC77F2757C8CFEF880D1835B5D415817310178A0340B8CAD5`
- `openocd.stderr.log` SHA-256：`E5C39F4CD300F9E966977639720106A30CF4781112B3D942306866303A314601`
- `openocd.stdout.log` SHA-256：`E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855`
- `openocd.combined.log` SHA-256：`CBDB88A74F32470260D3C9F2659ED97E209230733127019FF2D0207B2668A037`
- `result.json` SHA-256：`DE26C49461A4AC3658070A50865DA845A825AB9F90A0617024330D163B6C851B`

V75_SYSCTRL_DELAY_02 已结束且 marker 已消费，不能重跑。下一种可执行设计是将“最多一次 halt 2000、halt 后只读门槛检查、满足条件后唯一一次 PERI_CLKEN 写入及定时读回”放进同一个 OpenOCD 会话，避免跨会话状态变化；该新阶段需要新的独立授权。
