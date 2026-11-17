# V122 I2C 行为模型差分与下一步

## 实际离线实验
使用现有 V33 `i2c_behavioral_mmio.v` 和 `i2c_slave_bfm.sv`，Icarus Verilog 编译运行 `tb_v122.v`。先配置相同的时钟、分频、模式和模块位：
- 地址寄存器 0x3c，FIFO 只写 0x00：300 个仿真时钟后 starts=0、fifo=1、state=0、SCL/SDA=1。
- 模型复位、同样配置后 FIFO 写 0x78、0xA5：starts=1、stops=1、acks=2、fifo=0、payload=0xA5。
原始输出见 `simulation.log`。这是模型验证，未访问芯片。

## 源码依据和解释
V33 模型 `ST_IDLE` 仅在 enabled 且 `fifo_count==2` 时将 fifo_count 清零、进入 START；FIFO 第一字节作为 address_byte，第二字节作为 payload_byte。`addr_reg` 和 `master_ctrl` 存储并可读回，但状态机没有用它们决定地址或 STOP，STOP 由状态机自动生成。BFM 对 0x78 产生 ACK。因而模型单字节卡住是人为假设的直接结果，不能证明 ASIC 同样要求两个字节；先前模型 PASS 也不能验证 ARM 地址配置或 STOP 时序。
ARM `IIC_Master.c` 调用 SetAddr 后逐字节写 FIFO，监测 DATA、TX_NUM 和错误；V113/V115 已在 halted+SBA 下尝试相近顺序仍 TX_NUM=1。不能再声称重做相同顺序是全新实验。

## 下一项判别实验：写入发起者对照
基线需重新上电后确认 RST 释放且 FIFO 空。保留同一组配置和 OLED，使用硬件启动后自然执行的、可识别构建标识的最小固件，以 CPU volatile store 写同一 FIFO 字节并连续记录状态，和既有 SBA 样本比较。先单独证明 CPU 执行：使用本轮唯一 nonce 邮箱，记录启动前/后不同值，验证程序计数和完成标记，再进行 I2C。CPU 成功排空而 SBA 不排空支持发起者/访问时序差异；两者都停在 TX_NUM=1 则继续检查 START/地址、实际波形和器件版本，不足以证明 IP 故障。CPU 无法证明执行则不得把无结果当作 I2C 结果。

现存 V117C 使用旧邮箱并有 PC 回读不符，不能作为 SRAM 已执行的证据；V119 对 PC/DPC 仍有阻断。使用用户之前授权的 Flash 能力前，必须先核对当前镜像、擦除范围和可恢复性；若启动/恢复条件无法确定则不执行擦写。重新上电是当前软复位释放未确认下的先决条件，不能用额外写 STOP 构造结果。
