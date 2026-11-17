# V137 ARM引脚参数审查与驱动强度单变量实测

## 源码审查
D:/project/63300/CY63300_测试样例/IIC_Master.c 117–194行：PA0/PA1 AF5、输入浮空/低驱动/慢速；PB2/PB3配置GPIO_Mode_Out_OD、GPIO_Dr_High、GPIO_Sr_Fast、AF3，然后启用内部上拉。Device_lib/src/cj32l01xx_gpio.c 96–127行把DRIVE、SPEED、DIR按Pin掩码写入。Device_lib/inc/cj32l01xx_gpio.h枚举DriveHigh=1、Fast=0。数字手册DRIVE每位高驱动1，故PB2/3 DRIVE=0xC；OSOD=0xC、DIR=0xC、PUPD=0x300、AF=0x6C0、SPEED=0与本机已有设置相符。公司CY63300.c的另一工程I2CTest用不同引脚(PB0/1 AF2、PP)，不能不核对绑定图就照搬。

## 规划与实际执行
在V136活动卡点上先验证：CLKEN=0x21、RST=0、DIR/ODR/OSOD=0xC、AF=0x6C0、PUPD=0x300、SPEED=0、DRIVE=0、MODULE=0xF、ADDR=0x3C、FIFO=0x104、STA=1、RAW=0。采用写前读取不同安全地址ODR的策略，只写GPIOB_DRIVE 0x40000164 <-0xC一次，独立读回成功。之后10次轮询，全部FIFO=0x104、STA=1、RAW=0。

结果FIFO_STILL_QUEUED_AFTER_DRIVE_HIGH。写1次GPIO寄存器，未追加FIFO、STOP、I2C使能、Flash/NVR/SRAM写，未reset/resume，没有重试或自动恢复。初始running、halt一次后报告halted。最后读回DRIVE=0xC，采样FIFO仍1字且WORK=1；断开后CPU/寄存器状态未持续观察。

## 结论与限制
ARM驱动强度差异确实存在并已补齐，但在事务卡住后更改未使其自动恢复。不证明外部线路幅值、下拉驱动能力、START/ACK或总线时钟正常，不能排除发送之前设置High的条件差异；本轮不将其描述成已经完全排除电气因素。当前GPIO输出IDR不能替代实际管脚输入观察。

另一差异为ARM在PA0/1上的AF5去复用；其是否解除多输入SCL/SDA来源或与该RISC-V版调试脚/启动功能冲突尚未知，本轮未修改GPIOA。下一步先对照绑定表与所有输入SCL/SDA候选复用的门控语义，选择安全的单变量实验，而不是直接盲写GPIOA。

## 清单
- ARM PB2/3 DIR/AF/OSOD/PUPD/SPEED审查：已完成，本机值基本相符。
- ARM PB2/3 DRIVE High：已在卡住事务上实测写入，未恢复FIFO。
- 同High配置从新空闲启动：未完成。
- PA0/1 AF5差异与输入复用冲突：待审查；未写入。
- 真实波形/ACK、CPU store、OLED显示：未完成。

日志runs_local_v109/BBX_V137_ARM_DRIVE_HIGH_20261110_01_20261110_204751_239523，combined SHA256 8DFB9CED842ABC43BD5ACCDDAF50F4D1414710FCD98F3DDAB82D86F34BECB949。脚本03_experiments/v137_arm_drive_high.tcl，包装器run_v137_arm_drive_high.py，marker保留。
