# CY63300 V156 H2 硬件 I²C 主机实测

保留 H2-3/SCL、H2-4/SDA 到 OLED 与 STM32 的接线。根据 V150–V152 实测映射，将 GPIOC0/C1 的数字复用设为 AF3，GPIOC_AFR1 读回 0x1B。GPIOA/B 的 AFR1 均为 0。STM32 的 PB8/PB9 保持高阻，采样前确认两线空闲高。

CY63300 配置片上 I²C 主机、七位地址 0x3C，DIV0=DIV1=0x3E7。只向 TX FIFO 写一次 0x00。第一次状态读取已为 FIFO_STA=0x05、I2C_STA=0x03、RAW=0，对应 TX_NUM=0、WORK=1、DATA=1。发出一次 STOP 后，FIFO_STA=0x05、I2C_STA=0、RAW=0。全程 15 笔目标写，其中 13 笔配置、1 笔 FIFO、1 笔 STOP。

STM32 在 OLED 端独立记录 46 个边沿，捕获 START、0x78、ACK、0x00、ACK 和 STOP。两次 ACK 均为第九拍 SDA 低，捕获首尾两线均高，无溢出或模糊采样。按 STM32 72 MHz 计数器换算，前 18 个 SCL 上升沿之间的中位周期约 308.8 µs，即约 3.24 kHz。名义分频计算的 8 kHz 与该实测值存在差异，实际外设时钟需另行核对。

结论为当前实物的 H2 能输出片上硬件 I²C 主机时钟，OLED 地址和控制字均收到应答，STOP 后控制器回到空闲。手册的 PAD12 SCL 标注及当前载板的物理 PAD 编号仍需核对。本轮传送的是单个控制字，后续可在同一配置下验证完整显示命令和显存数据。

CY63300 合并日志 SHA256 4092993068946D9AB7E09D903590DD0A8839753195B8FB60F470D3379598B543。保留 STM32 原始邮箱、边沿 CSV、解码、独立 marker 和离线回归结果。
