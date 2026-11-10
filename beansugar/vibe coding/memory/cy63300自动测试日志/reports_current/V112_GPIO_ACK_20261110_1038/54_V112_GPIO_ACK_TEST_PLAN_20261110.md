# V112：GPIO 开漏模拟 OLED 地址 ACK

## 目的

独立于 I²C 控制器，使用 Pad8/SCL(GPIOB2)、Pad9/SDA(GPIOB3) 软件产生一帧 7-bit 地址 `0x3C + W`，在第九个时钟采样 SDA ACK。由此区分外部线路/OLED 应答路径和硬件 I²C 控制器 TX/START 路径。

## 门禁已完成

V112A0 只读预检通过：IDCODE=`0x1E200A6F`、DMSTATUS=`0x00430382`、SBCS=`0x20040404`；CLKEN=0、RST=0，CPU 初始运行后 halt 一次。目标 MMIO 写入 0。原始日志 SHA256：`5F2D77542FBCFEE42E5BC8661D748EAE66499212EF9364D4FF7B02FED5027A25`。

## 有条件执行

1. 单独开启 GPIO 外设时钟 bit0；不打开 I²C 时钟。
2. 先将 GPIOB2/B3 输出锁存置 1（开漏释放），再使能开漏和输出方向；AFR1 必须确认两个脚均为 GPIO 功能。保留其他 GPIO 位，不操作内部上拉字段。
3. 确认两线输入采样均高后才发 START。
4. 软件输出 START，发送地址字节 `0x78`（`0x3C` 左移一位并加 W=0），在第九个 SCL 高电平期间采样 SDA：低=ACK，高=NACK。
5. 无论 ACK/NACK，都只发一次 STOP 并释放两线。若任一引脚未按预期释放/拉低，立即中止并释放两线。

## 限制与判读

- 这是一次低速 GPIO 软件 I²C 地址探测，不配置 SSD1306，不发送命令/显示数据，不会显示 Hello。
- 只测试地址 `0x3C`，不扫描 `0x3D` 或其他地址。
- ACK 说明 Pad8/Pad9、上拉和 OLED 地址响应路径可用；NACK 不能单独证明 OLED 损坏，还可能是地址绑带或线路电气问题。
- GPIO ACK 通过而硬件 I²C 仍卡 FIFO，则下一步集中检查硬件控制器 START/地址阶段、握手/RTL 版本差异。
- 失败时不自动重试，不复位，不继续硬件 I²C；日志保留实际引脚采样与错误原因。
