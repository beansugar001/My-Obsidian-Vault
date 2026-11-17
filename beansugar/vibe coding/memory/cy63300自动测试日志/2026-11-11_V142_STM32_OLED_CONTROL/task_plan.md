# V142 STM32 OLED 对照

- [x] 核对 4-1oled 的 GPIO 开漏、地址、显示及调试工具
- [x] 从 ST-Link 读取 STM32 身份、现场与现有固件
- [x] 编译并校验 SRAM 临时探测程序
- [x] 读取 0x3C/0x3D 的第九拍，确认原 Flash 未更改，恢复原程序并归档

4-1oled 的 SCL/SDA 为 PB8/PB9，开漏，向 7 位 0x3C 写入并显示 HelloWorld。原样例不读取 ACK。V142 用 ST-Link/SWD，只在 STM32 上测试，优先临时 SRAM 运行；OLED 目前接在 STM32 上。以实际的 GPIOB IDR 第九拍和固件邮箱取证。CY63300 调试器与电源保持用户已接状态，V142 不对 CY63300 发任何命令。

- 01 连接成功，状态检查早停，未 Halt 或加载。02 显式 poll 后完成对照，0x3C ACK、0x3D NACK，原 Flash 逐字节相同，恢复运行。
