# V127 已卡事务增加内部上拉的判别实验

## 目标与背景
V126 通过 SBA 写入单字节后，TX_NUM=1、WORK=1、DATA=0。检查到 GPIOB_PUPD=0；V112 GPIO 位模拟实验中内部 PUPD=0x300 时输入采样由低变高，第九位仍 NACK。用户已确认 OLED 可用和接线。此次检验在已有卡住事务上增加已用过的内部上拉，是否促使其前进；不把该测试解释成有示波器电气证据。

## 实际结果
重连只读 V127 发现 CPU initial reported running，单次 halt 后 FIFO_STA=0x104、STA=1、RAW=0、CLKEN=0x21、RST=0、PUPD=0；因未持续监控，不证明 CPU 在整个断连期间运行。随后另一新会话校验 FIFO=0x104、STA=1、PUPD=0、AF=0x6c0、MODULE=0xf 等，写 GPIOB_PUPD 0x4000015C <- 0x300 一次并独立读回；IDR 前后 0x2c。10 次采样 fifo=0x104、sta=1、raw=0、idr=0x2c；无 FIFO 消耗。目标 MMIO 写1次，没有写FIFO/STOP、复位、resume或Flash/NVR。PUPD最后确认0x300，其余状态是停止时采样，调试断开后状态待实测。

该结果只排除“已卡住后补内部上拉立即恢复”的方案；不能排除开始事务前就要配置上拉、外部上拉不足、外部连接器电压和波形异常、时钟停顿或 IP 状态机/地址问题。没有观测到ACK不能说已收到NACK。

## 参考证据
TinyRISC-V 参考 `rtl/core/ctrl.v` 中 jtag_halt_flag 作用于流水线 hold；`rtl/soc/tinyriscv_soc_top.v` 中 timer/uart/gpio/spi 和RIB均直接接 clk，非由 halt 明确门控。但参考 top 没有流片 CY63300 I2C RTL，不能由此断言 ASIC I2C 在halt时持续运行。ARM `IIC_Master.c` 为活动CPU配置地址后写一个字节并轮询，STOP 修复发生在 DATA已出现且TX_NUM=0的阶段；本实测停在更早阶段。V33行为模型为假设两个FIFO字节后自动启动，不是厂商IP，不能据其要求硬件增加字节。

## 下一步判别
1. 用户重新上电后先确认 reset释放、空闲，然后在使能/发送之前写 PUPD=0x300，再使用相同的单字节发送，比较结果；与本次补上拉不同。该测试若仍卡，不能说外部上拉足够，需要测 OLED连接器 SDA/SCL 电压与时钟。用户已有示波器，但接触短路顾虑应优先安全固定测试点。
2. 更强对照是让已证明执行的CPU按ARM单字节路径运行；V119B DPC 写入导致 running且入口读回异常，邮箱无新标记，V125读取 DPC不只是DATA0残留。需先解决可验证启动和现有固件副作用，不能把运行状态误认为执行成功。
3. 任何新测试前确认现状与保留备份；若需重上电应由用户操作，不能以重复写或FIFO塞满作为恢复方案。

只读快照 `runs_local_i2c_next/BBX_V127_RECONNECT_STALL_SNAPSHOT_20261110_01_20261110_193616_143657`，combined SHA256 `0CC73B6BAB4A02253CD0CDEA3397BCE421F723F4FB1E54B27EB0CA9924300E73`；上拉阶段 `runs_local_v109/BBX_V127_PULLUP_STALLED_20261110_01_20261110_193722_844748`，combined SHA256 `D97E03C1046E2EEEAF4AA40FE1F47B2308EB24BBB77219B8604EC9F7B3D5D6C0`。两个独立 marker 均保留。
