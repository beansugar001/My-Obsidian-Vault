# V136 写前地址切离：直接0x3C使能通过，FIFO仍卡住

## 规划与范围
不使用临时地址0x50。沿用V133/V134/V135的每笔写前读取不同安全地址策略，按ARM参数配置GPIO/I2C，直接ADDR=0x3C后使能。配置/空闲预检通过才单独发一字节0x00。无软复位、Flash/NVR/SRAM写、CPU resume或自动重发。新marker独立保存。

## 初始化实际结果
前置CLKEN=1、RST=0、GPIO DIR/AF=0、PUPD=0x300、ODR=0、OSOD=0xC。
12次固定目标写：CLKEN=0x21；GPIO ODR=0xC、DIR=0xC、AF=0x6C0；DIV0=DIV1=0x3E7；MCTR=0；HOLD=5；MODULE=0xC（读0xE）；MODE=1；ADDR=0x3C；MODULE=0xD（读0xF）。每次先读取不同地址安全寄存器，目标写后独立读回。
最终MODULE=0xF、ADDR=0x3C、FIFO_STA=5、I2C_STA=0、RAW=0、RST=0、PUPD=0x300。结果PASS_DIRECT_3C_ENABLE_PARKED_FIFO_EMPTY。
因此本次不用0x50也能使能；之前0x50绕行与“不同地址访问”混杂，不能再视为必需硬件解锁值。仍不能断言ASIC唯一根因为地址边沿，V134也存在额外读取时间/事务差异。

## 单字节实际结果
新独立会话复核上述配置、空闲和错误状态。读取ODR=0xC切离后，设置SBA写模式和地址0x40002808，只写SBDATA0=0一次，检查busy/error，再轮询60次。
首轮、末轮及最终均：MODULE=0xF，ADDR=0x3C，FIFO_STA=0x104（TX_NUM=1），I2C_STA=1（WORK=1/DATA=0），RAW=0，seen_data=0、drained=0、nack=0。SBCS最终0x20040404，未报busy/error。结果FAIL_TX_STALLED_NO_DATA_NO_NACK。
目标FIFO写1次，STOP写0次，没有重发或恢复。写0x00只是OLED命令控制字，未完成命令帧或显示数据；无NACK标志不等于ACK。未捕获外部波形，采样可能错过瞬态，不能据此断言没有START。

## 本轮信息增量
- 已完成并通过：全部12次配置写读回；直接0x3C使能（无0x50）；空FIFO/空闲基线。
- 已完成但失败：采用同策略的单字节FIFO消耗。
- 未完成：真实线上地址/ACK、START波形、CPU/SBA差分、厂商真实I2C RTL、OLED Hello。
- 已不支持作为充分解释：仅靠临时地址使能顺序、仅靠同地址写触发问题即可解释所有FIFO卡顿。该策略对控制寄存器有作用，但并未解决发送状态推进。

## 当前状态/下一步
最后采样FIFO=0x104、WORK=1，GPIO AF3且DIR输出。输出模式IDR不可当作物理线路高电平证据；本轮未读取其值作为总线准入。调试断开后实际状态未再观测。
应保存此现场，不追加字节/STOP、不开启软复位恢复。后续优先查ARM GPIO复用输入路径及真实主FSM启动条件；无仪器情况下只能做数字输入对照，不能宣称替代物理地址/ACK捕获。CPU对照仍需可靠执行入口/唯一邮箱验证。若新上电测试，所有配置会丢失，需要明确单变量并新marker，不简单重复本轮。

## 日志
init runs_local_v109/BBX_V136_PARKED_DIRECT_I2C_INIT_20261110_01_20261110_204323_927321，combined SHA256 7BFCC6A703601EF8F6D6BCC03F85EC90CD9444E6D4603FB18E53D2CBEE0A1F62。
TX runs_local_v109/BBX_V136_PARKED_FIFO_20261110_01_20261110_204438_703633，combined SHA256 D931332C9A9B804564A5A177C7B9BC3B847DE1E1682A75843D4393E95C7A2C8D。
总目标MMIO写13次，初始化12+FIFO1；各会话最多一次halt，两个marker均保留。实际源码路径03_experiments/v136_parked_direct_i2c_init.tcl、v136_parked_fifo_once.tcl；runner使用审阅Tcl哈希固定，原有V115E/F日志标签是复用实现，不代表重复旧运行。
