# V124 CPU FIFO 对照启动检查

用户要求 CPU 按相同配置写 FIFO 并持续轮询。核查发现当前 V118 固件并非同配置：它先脉冲 PERI_RST[5]，而该释放路径近期实测未可靠释放；分频 0x3E7/0x3E7 与 V113 的 0x0F/0x23 不同。因此不能把它直接作为相同条件对照。

V124 独立会话：JTAG IDCODE=0x1E200A6F，初始 running，单次 halt 后 reported halted，DMSTATUS=0x00430382，SBCS=0x20040404，pc=0x64、dpc=0x64、dcsr=0xC0，PERI_CLKEN=0，PERI_RST=0。没有 SRAM、MMIO、Flash/NVR 写入，也没有 resume。I2C FIFO CPU store 未执行。原始日志 SHA256 0CA79E73E2F66F8F24CFC9EB206C1B17CBE8340E6DDE9DB9D2551E366D2F8FB6。

0x64 与 V118 旧报告的 PC 读回一致，且是其 0x62 处 32-bit 指令的后半字，不能将该数直接认定为可执行入口，也不能单凭其认定 CPU 真实 PC。TinyRISC-V 参考 `rtl/debug/jtag_dm.v` 的 abstract COMMAND 对 DCSR 和 GPR 提供读路径，但没有对应 DPC 读取分支；写 DPC 会触发 dm_reset_req 并清 dm_halt_req。这是解释读回异常与运行状态变化的候选，真实 ASIC 是否相同未知。需要核实厂商 Debug Module 实现或针对读取建立可区分新旧 DATA0 的无侵入性验证。

V123 上电后的 V118 邮箱未出现唯一开始/完成标记；不能据此证明 CPU 从未执行。要完成用户指定对照，应准备不脉冲复位、配置与 SBA 基线一致、仅写一字节并写本轮唯一邮箱的固件；先解决执行入口与结果读取，且确保退出会话不会意外执行未经审计的现存固件。严格禁止把旧 mailbox 当本次成功。
