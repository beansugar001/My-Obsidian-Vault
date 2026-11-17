# V128 发送前内部上拉对照结果

用户重新插拔后测试：使用与 V126 相同的 ARM 风格 SBA 顺序和参数，改变为在控制器初始化及发送前把 GPIOB_PUPD 设置为0x300，并在发送前再次读回。

实测：CLKEN=0x21、RST=0；PAD阶段 ODR/OSOD/DIR=0xC、AFR1=0x6C0、PUPD=0x300，GPIO输入采样0x2C。ARM 原顺序的 I2C_EN 写0x0D后读0x0E，失败于发送前；沿用 V126 已验证的临时地址0x50、I2C_EN、最终地址0x3C 顺序，读回 module=0x0F、FIFO空、WORK=0。发送前确认 PUPD=0x300，向 TX FIFO 写 0x00 一次。60次轮询首尾均 FIFO_STA=0x104、STA=0x1、RAW=0，seen_data=0、drained=0、nack=0，STOP写0次。

与 V126 发送前 PUPD=0 的结果相同：两次均未观测到 FIFO 消耗。只能说本测试条件下提前设芯片内部上拉未解决故障；GPIO IDR及弱上拉不能确认外部线路的电平幅值、上升时间、上拉电阻、ACK或START波形。NACK标志为0不是收到ACK的证据。FIFO最后采样非空、WORK=1，断开调试器后实际状态待复核；未自动重新发送、复位或恢复。

五阶段目标 MMIO 写次数：clock 1、pad 5、ARM init 8、enable 3、TX 1，总计18。未写Flash/NVR或执行CPU程序。各阶段运行目录位于 runs_local_v109/BBX_V128_*；marker保留。TX combined SHA256 `FA2CBC8D609BEF85F58EDC596621EE782F4C3310FF9098B5E06A4DB7BDEF03E4`。

下一步最具判别力：安全固定探头在OLED接头端，观察SDA START与SCL，区分控制器未驱动、地址未被应答与线/时钟问题；用户若无法安全连接，应考虑可接的测试夹或在断电时接引线。并行离线查厂商 Debug Module/启动协议以建立 CPU store 对照；参考 V33 I2C 为行为mock，不能替代芯片波形或真实IP。
