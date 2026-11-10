# V117A：V116B 后只读状态检查

## 结果：BLOCKED，未读取外设寄存器

OpenOCD 能连接到预期 CMSIS-DAP（序列号 `07000001006700343500000a4e57354aa5a5a5a597969908`）并识别唯一 TAP，IDCODE 为 `0x1E200A6F`。但 CPU 状态读为 **running**；V117A Tcl 按安全门槛停止，没有发送 halt，也没有读取 DMSTATUS/SBCS 或任何目标 MMIO 寄存器。因此当前无法判断控制器 FIFO/WORK 是否空闲。

本轮目标 MMIO 写次数为 0，DMI 仅用于连接/目标检查；未复位、resume、烧录或访问 Flash。日志末尾：

```text
V117A_CPU_STATE=running
V117A_ERROR=CPU_NOT_HALTED_NO_MMIO_READS
shutdown command invoked
```

OpenOCD 初始化行同时打印 `misa=0xc`，与历史值不同。由于本次未完成 halted 状态下的 DMSTATUS/寄存器读取，该值仅记录为连接时异常观察，不能说明 CPU ISA 或芯片配置真的变化。

## 主机互斥检查缺陷

PowerShell 的 `Get-CimInstance Win32_Process` 返回“拒绝访问”。执行入口没有将该非终止错误升级为阻断错误，仍继续启动 OpenOCD。虽然本轮实际只进行了只读连接并在 CPU 门槛停止，但执行器不符合既定安全要求。后续入口必须使用 `-ErrorAction Stop`；进程/监听器查询失败即退出，且不得启动 OpenOCD。当前阶段 marker 与日志保留，不重跑该阶段。

## 执行记录

- 阶段：`BBX_V117A_POST_V116_READONLY_20261110_01`
- 目录：`C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX\runs_local_v116\BBX_V117A_POST_V116_READONLY_20261110_01_20261110`
- OpenOCD：`D:\project\tools\tinyriscv-master\tools\openocd\openocd.exe`
- 配置 SHA256：`1275374EA7E2E976B7E0F86D48EE2E9389C344B4A8C36D38F215D5E1D36656B4`
- Tcl SHA256：`E377457464C3A4EEF3459DF82C466A74F0A4444F1542CCAC062C3791CFD22E5C`
- OpenOCD SHA256：`EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27`
- 原始 combined log 在执行目录中；本次 Tcl 没有报告任何 `V117A_READ` 或 `V117A_DMI` 行。

## 下一步

1. 用户对目标板完整断电再上电，清除 V116B 后可能遗留的 I²C 状态并回到确定启动状态。
2. 下一次连接前，先修正主机进程互斥检查：枚举失败必须 fail-closed；禁止只因 OpenOCD 可连接就继续。
3. 新阶段只读确认 IDCODE、CPU halted 状态、DMSTATUS/SBCS、PERI_CLKEN/RST；时钟有效后确认 FIFO 空、WORK=0、RAW=0。任何门槛失败立即停止。
4. V117 的 948 字节 SRAM 固件已离线编译，链接到 `0x20008000..0x200083B3`，邮箱位于 `0x2000F000`，栈顶为 `0x20020000`。它按 ARM 轮询流程逐字节发送 `0x00` 与 `0xAE`，仅在数据阶段观察到且 TX_NUM=0 时才送第二字节/STOP；不写 Flash、不做软件复位。该固件尚未加载或运行。
5. 当前必须等用户完成断电重上电后再继续真实测试。不要在 CPU running、状态未知或进程审计失败时装载 SRAM 程序。
