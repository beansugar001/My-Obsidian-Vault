# V125 DPC DATA0 哨兵实测

## 测试目的
区分 DPC 读回 0x64 是否只是 DATA0 保留之前写入的数据。当前 Flash V118 含软复位与不同分频，尚不能做同配置 CPU FIFO 对照；V119B 曾写 DPC 后 hart running，但 DPC 不等于 SRAM 入口，邮箱无唯一标记。

## 实际操作
同一 OpenOCD 会话内识别 TAP/IDCODE，初始 running、单次 halt 后 reported halted；DMSTATUS/SBCS 检查后读取 ABSTRACTCS。向 Debug Module DATA0 写入不同测试图样，每次验证 DATA0 后发送 abstract CSR read DPC 命令 `0x002207B1`，检查 ABSTRACTCS，再读 DATA0。仅写 DMI 的 DATA0/COMMAND，未写 DPC、CPU GPR、目标 MMIO/SRAM/Flash/NVR，未发送 resume 或 reset。该路径由 V123 包装器复用，CLOCK_OFF_NO_I2C_READ 只反映时钟分类，不是本项哨兵判定。

| DATA0 初值 | DPC 读取后 DATA0 | ABSTRACTCS |
|---|---|---|
| 0x5A39C6A5 | 0x00000064 | 0x01000003 |
| 0xA5C6395A | 0x00000064 | 0x01000003 |

说明 DPC 读取结果并非直接保留先前的两个 DATA0 值；尚不能证明 0x64 是真实执行 PC，也不能证明 DPC 可写或 SRAM 可执行。不能把参考 RTL 的 DPC 行为当作流片事实。CLKEN=0、RST=0；没有进行 FIFO 或 CPU-store 测试。

原始 combined log SHA256 `197BAD2F5A65AA3453A63DA821AEF40BFC10C98EC9098DBDFDB03C1ECD655AA7`；阶段 `BBX_V125_DPC_SENTINEL_20261110_01` marker 保留。

下一步应核实供应商调试模块 DPC 的读写、0x64 返回与启动向量映射，或获得匹配 OpenOCD 0.10.0+dev-00914 的源码。必要时先用不会触及 I2C 的唯一邮箱 canary 验证 CPU；只有入口和恢复路径可信后才进行与 SBA 参数相同的 CPU 单字节对照。现有 V118 启动会自行脉冲 I2C 软复位并修改分频，直接启动会混入额外变量。
