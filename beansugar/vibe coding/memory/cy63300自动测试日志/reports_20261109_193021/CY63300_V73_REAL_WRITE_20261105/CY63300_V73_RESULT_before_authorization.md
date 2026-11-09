# CY63300 V7.3 结果

日期：2026-11-05（Asia/Shanghai）  
状态：**PREPARED — WAITING FOR EXPLICIT V7.3 HARDWARE AUTHORIZATION**

## 本轮实际执行边界

V7.3 请求本身将实际 Halt 和 MMIO 写入标为“拟授权范围”，并明确要求执行前取得用户对 V7.3 的明确批准。本轮没有获得该项单独批准，因此只做了本地 OpenOCD 命令能力核验及脚本静态审查，**没有连接 CMSIS-DAP、没有初始化目标、没有发 Halt、没有读取/写入目标寄存器，没有创建 V7.3 硬件阶段 marker**。V7.2 marker 保持原样。

因此，真实芯片 Halt 结果、PERI_CLKEN 与 CLK_DIV0 读写结果当前均为 **NOT EXECUTED**，不是 PASS 或 FAIL。

## OpenOCD 命令能力核验

当前可执行文件：`D:\project\tools\tinyriscv-master\tools\openocd\openocd.exe`  
版本：`0.10.0+dev-00914-g4cb81306a-dirty (2020-01-28-21:35)`  
SHA256：`EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27`

不加载目标配置的 OpenOCD 命令检查确认 `target current` 已注册。使用 V7.2 无 halt 配置、同时执行 `noinit` 的主机侧检查，`target current` 返回 `riscv.cpu`；`riscv.cpu curstate` 命令被识别，但明确返回“must be used after init / Target has not been initialized”。这表明不能在未初始化目标时读状态，也没有因此访问真实目标。

V7.3 新配置也以 `noinit` 运行过一次纯配置检查：没有出现 CMSIS-DAP 初始化、JTAG 扫描或目标访问输出；`target current` 返回 `riscv.cpu`。这只核对配置语法与命令注册，没有初始化或连接芯片。

该二进制的可执行文件字符串包含 halt 请求处理器、等待指定毫秒数完成的命令帮助文本及 RISC-V halt 处理符号。由于 halt 命令在未初始化目标时不可用，本轮没有对真实目标执行 `halt 2000`。OpenOCD 官方命令文档定义 `halt [ms]` 为发送 halt request 并等待指定时长；CPU 配置文档定义 `<target_name> curstate` 输出 `halted/running/...` 状态。链接：[General Commands](https://openocd.org/doc/html/General-Commands.html)、[CPU Configuration](https://openocd.org/doc/html/CPU-Configuration.html)。

## 修复准备

- 新配置：[v73_100k_no_servers.cfg](v73_100k_no_servers.cfg) 使用 CMSIS-DAP/JTAG、100 kHz，并在初始化前关闭 GDB、Telnet、Tcl 监听。
- 新 Tcl：[v73_real_write.tcl](v73_real_write.tcl) 不解析 `targets` 输出表格；执行时会先用 `target current` 选中 `riscv.cpu`，再读 `riscv.cpu curstate`。若为 `running`，最多发送一次 `halt 2000`，随后再读对象状态并检查 DMSTATUS halted 位。halt 失败或状态不符即停止；没有 reset/resume/重试。
- 目标 MMIO 白名单只有 `0x4002180C <- 0x00000020` 与 `0x40002810 <- 0x00000021`，累计最多两次；第二次写只在第一项通过后继续。没有恢复写。
- 脚本等待 SBA busy 清零后检查 SBCS；目标写后通过独立 SBA 读事务复核。
- 静态安全门禁通过：端口关闭 3/3、target current/curstate/Halt 调用存在、两组写值白名单匹配、未发现 `mww`、reset、resume。
- V7.3 硬件 marker 尚未创建。授权后才创建一次性 marker 和运行日志目录；不复用 V7.2 阶段记录。

文件哈希：

| 文件 | SHA256 |
|---|---|
| `v73_100k_no_servers.cfg` | `6770C370510C16FE1CF964ABF2F9D702743F5DF75F61890179F42415836D0B9B` |
| `v73_real_write.tcl` | `8FDE615A09B86A00D5CCF27EDF8EA1585310D6D2AABBDC6CE3C9DD8AA277B5D3` |

## 执行前需要的明确批准

若批准，单次 V7.3 阶段将按配置以 100 kHz 运行；halt 最多一次；PERI_CLKEN 写最多一次；条件满足时 CLK_DIV0 写最多一次；失败即停。不执行恢复、reset、resume、Flash/NVR、断电或任何其他目标写入。实际启动时会先运行不连接目标的主机进程冲突检查；发现调试客户端冲突则不启动 OpenOCD。真实操作前会创建新的独占 marker 并保留完整 stdout/stderr/命令/哈希。

**当前未获该项批准；不得运行本目录的硬件 Tcl。**
