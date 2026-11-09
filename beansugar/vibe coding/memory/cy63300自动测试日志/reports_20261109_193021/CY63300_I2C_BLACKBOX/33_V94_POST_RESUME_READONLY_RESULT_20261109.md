# V94：V93 后 CPU/DPC 与 I²C 状态只读复核

阶段：`BBX_V94_POST_RESUME_READONLY_01`  
结果：`PASS_READONLY_SNAPSHOT`  
OpenOCD 合并日志 SHA256：`B4182D987AE0F3566FFBC7EEBB6D1D0DB85D1C538FF4E58D7ED89FC0FB5DD05A`

## 读数

- 重新连接时 hart 为 running；一次 `halt 2000` 后状态为 halted。
- DMSTATUS 连读稳定：`0x00430382`。
- SBCS：`0x20040404`，本次 DMI 检查时无 busy/error。
- DPC 连读两次：`0x2C006DD2`，一致。
- DCSR 连读两次：`0x000000C0`，一致。
- 当前 I²C 状态：CLKEN=`0x21`、RST=`0`、MODULE_CTRL=`0x0F`、FIFO=`0x05`、DIV0/1=`0x3E7`、ADDR=`0x3C`、STA/RAW=`0`。
- GPIOB IDR=`0x2C`，Pad8/SCL 与 Pad9/SDA 输入均为高电平。

目标 MMIO 写入 0，Flash/NVR 写入 0；本阶段没有 resume、reset 或断电。

## 对 V93 的解释

V93 resume 错误中报告的读回 PC `0x2C006DD2` 与 V94 独立读出的 DPC 完全一致。说明错误不是日志误解析：OpenOCD 请求把 PC 设为 `0x20008000` 后，目标仍回报原 DPC。邮箱未变化，V94 又确认 I²C 控制器和 Pad 状态保持在 V93 前的空闲值。因此最强的当前阻塞是 **Debug Module 的 DPC/PC 写通路或 OpenOCD 对该 target 的 PC 写入适配**，不是 SRAM 镜像装载、I²C 初始化或总线空闲状态。

`DCSR=0xC0` 且 DPC 稳定只能描述当前 debug CSR 状态，不能仅凭此宣称芯片 CPU 本身损坏。V77 的 GPR 抽象读写测试可见，但 Program Buffer `addi` 未执行可见；因此先单独验证 DPC 写回可逆性，再考虑任何 CPU 执行。

## 下一步候选

新阶段中保存 DPC 原值 `0x2C006DD2`；通过抽象 CSR 写请求将 DPC 临时设为 `0x20008000`，马上读取确认；无论成功与否，按独立清晰的恢复步骤写回原值并读回核实。该测试不 resume CPU、不发 I²C、不访问 Flash/NVR。若 DPC 无法设置或无法恢复，立即停止 CPU 执行路线并保留状态；若设置与恢复都通过，才重新准备一个基于 DPC 的 RAM canary 方案。
