# V90 GPIO I²C 地址探测结果（2026-11-07）

## 本轮结论

CY63300 通过 GPIO 开漏方式在 Pad8/PB2（SCL）、Pad9/PB3（SDA）上发送完整的 SSD1306 写地址字节，并在第 9 个时钟采样 SDA。默认地址 `0x3C`（线上 `0x78`）和备选地址 `0x3D`（线上 `0x7A`）都得到 NACK：采样值为 `SCL=1、SDA=1`。测试随后产生 STOP，GPIO 输入读回两线均恢复高电平；最终 SBCS 为 `0x20040404`。

这确认目标侧 GPIO 读写路径可以形成并采样完整地址时序，但 OLED 没有在两个常见地址上应答。它不单独证明 OLED 模块损坏或接线错误：当前软件读回来自芯片 GPIO 输入寄存器，尚无 OLED 接口处的独立示波器波形或电压测量。

## 分阶段实测

| 阶段 | 实验 | 结果 | 目标写次数 | 综合日志 SHA256 |
|---|---|---|---:|---|
| `BBX_V90_GPIO_DIR_SCL_RECOVERY_01` | 用 DIR 先释放 SCL、预装 ODR 低、再切输出拉低；完成 STOP | `PASS_DIR_TOGGLED_SCL_AND_STOP_IDLE`；IDR=`0x2C`，SCL/SDA有效位=`0xC` | 8 | `FF1CFF06B94EAF478FE8D9A36189D2C975E796CC3BEE8DAB3EF8C62998F849CA` |
| `BBX_V90_GPIO_ADDRESS_ACK_06` | 单次发送地址 `0x78`（7位 `0x3C`） | ACK采样 `IDR=0x2C`、有效位=`0xC`，该样本本身是NACK；阶段标成FAIL是脚本误把ACK后SDA高误期待为低。安全STOP清理成功 | 39（含异常清理的8次） | `F1D5A9CB636D14A6CB9C00F2F345CBB847CC8D715B57990117205C0FA1BE556E` |
| `BBX_V90_GPIO_ADDRESS_ACK_07` | 新阶段单次发送地址 `0x7A`（7位 `0x3D`） | `PASS_ADDRESS_NACK_STOP_IDLE`；ACK采样 `IDR=0x2C`、有效位=`0xC`；STOP后仍=`0xC` | 37 | `7DCF5E02A1A8F7B48C58FF9F4F04C0D2CE5891C33DD3F2C899B508F748FA6249` |

阶段06的程序判定错误发生在ACK采样之后的时钟下降沿检查：从机未拉低SDA时，SDA在SCL拉低后仍然为高，正确预期有效位是`0x8`；脚本误期待`0x0`，因而把已观测到的NACK标为不确定。本报告保留原始日志和原状态，不改写历史`result.json`。阶段07修正该预期，并独立确认`0x3D`也NACK。

## 执行约束与证据边界

- 探针序列号：`07000001006700343500000a4e57354aa5a5a5a597969908`。
- 每阶段检查TAP、CPU halted、DMSTATUS、SBCS、时钟/复位、硬件I²C禁用、FIFO/状态空闲和GPIO状态。
- 除GPIO ODR/DIR外未写I²C控制器寄存器；未写OLED命令或显示数据；无复位、resume、Flash/NVR或自动重试。
- 本地STM32示例`D:\project\stm32\4-1oled\Hardware\OLED.c`发送地址字节`0x78`；OLED模块资料记载D/C#绑高时可用`0x7A`。两个候选地址均有资料依据。
- 用户报告OLED可用且接线正确。软件实测显示两个地址均未收到ACK；不能据此判定模块损坏，也不能区分OLED接口供电/连线与芯片Pad到模块端的实际波形。

## 下一步

暂停初始化命令和显示数据。下一项最有区分度的证据是在OLED四针接口处独立确认3.3V供电，并捕获一次SCL/SDA地址帧，重点观察第9个SCL高电平期间的SDA。探头应固定在OLED连接器或延长线上，地夹先接同一块板的GND，避免手持探针触碰电脑主板或芯片相邻焊点。

1. 接口处没有START/8个地址时钟：检查芯片GPIO到Pad/载板路径或观测点映射。
2. 接口处看到地址`0x78`/`0x7A`，ACK时SDA保持高：外部从机未应答；核对OLED供电、接口端连线和实际控制器/地址绑带。
3. 接口处ACK时SDA被拉低，但芯片IDR仍读高：调查CY63300输入采样、Pad复用或绑定关系。
4. 接口处ACK与芯片IDR都读低：进入ACK后的最小`0xAE`命令帧，不直接发送整套初始化。

结果目录：

- `runs\BBX_V90_GPIO_DIR_SCL_RECOVERY_01_20261107_113500_747221`
- `runs\BBX_V90_GPIO_ADDRESS_ACK_06_20261107_114025_190420`
- `runs\BBX_V90_GPIO_ADDRESS_ACK_07_20261107_114149_696748`

下一阶段示波器连接和设置：[24_V90_SCOPE_CAPTURE_SETUP_20261107.md](24_V90_SCOPE_CAPTURE_SETUP_20261107.md)。ACK08脚本已完成并通过28项离线回归；尚未创建marker、未连接硬件。必须先由用户确认探头已在OLED接口处接妥、Single已待触发，再执行一次。
