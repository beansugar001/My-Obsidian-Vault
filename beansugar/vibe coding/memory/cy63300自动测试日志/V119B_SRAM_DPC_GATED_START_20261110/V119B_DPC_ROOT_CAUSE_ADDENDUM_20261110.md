# V119B 根因补充：DPC 写触发复位的证据

日期：2026-11-10

## 观测

V119B 将 76 字节 canary 写入 SRAM `0x20008000` 并校验通过。随后按抽象寄存器协议仅写一次 `DPC=0x20008000`：先写 DMI DATA0，再发 COMMAND。ABSTRACTCS 保持 `0x01000003`；DPC 随后读为 `0x64`，hart 进入 running。只发一次 halt 后邮箱仍未变，说明 CPU 从 SRAM 入口执行未获证。SRAM 代码区与 20 字节邮箱均恢复并校验。

## 参考 RTL 对照

参考快照 `D:\project\RISCV-63300\CY63300_AUTO_TEST_V60\snapshots\reference_rtl\debug\jtag_dm.v`（SHA256 `F918FD2BF8BD700DC001894951048CFC2D1D2549B5B010D0AD953229E4A3F543`）约 252–256 行：DPC 写分支置位 `dm_reset_req`、清 `dm_halt_req`、把状态标为 running；它没有走普通寄存器写入分支中的 `dm_reg_we`。这能解释“DPC 写后 hart running、PC/DPC 并未保持 SRAM 地址”的实测表现。

这是参考 RTL，不是流片芯片 RTL；只能说高度吻合，不能据此宣称已证明 ASIC 内部实现。设计手册给出 Flash 地址范围从 `0x00000000` 开始，但未在当前提取文本中找到 CPU reset vector= `0x64` 的定义。因此 `0x64` 当前只应记录为实测 DPC 读值，不能直接叫作启动入口。

## OpenOCD 风险

可用 TinyRISC-V OpenOCD fork 中：

- `riscv-013.c`：DPC/PC 写先 DATA0 后 COMMAND，再读回 DPC。
- `riscv.c` 的 `resume_prep`：设置 PC 时没有检查 `riscv_set_register()` 的返回值，可能在 DPC 回读不等于目标地址后仍继续发送恢复请求。
- 该源码与本机 2020 dirty OpenOCD 二进制未证明是同一构建，只作为实现路径线索。

## 下一步

暂停 DPC 写和 `resume <address>`。先在设计说明、实际连线 RTL/boot 控制资料中查明复位入口、debug reset 对 hart 的作用，以及是否存在受支持的 SRAM 启动/PC 设置接口。后续若依赖 Flash 启动，须单独核对镜像布局、备份和擦写范围，不能直接复用旧烧录流程。
