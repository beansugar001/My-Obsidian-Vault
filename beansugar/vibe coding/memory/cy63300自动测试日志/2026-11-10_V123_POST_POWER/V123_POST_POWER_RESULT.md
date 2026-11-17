# V123 上电后 CPU 与 I²C 状态

重新上电后，独立只读快照识别 IDCODE 0x1E200A6F，DMSTATUS 0x00430382，SBCS 0x20040404。PERI_CLKEN=0，PERI_RST=0，I²C 时钟关闭，未读取其内部寄存器。目标 MMIO 写入0，未复位、resume、写 Flash/NVR 或 FIFO。

第二个只读阶段读取 0x2000F000 共40字，word0=0，word1=0x769E705A，word39=0x9F941934；不含 V118 启动标志 0x11780001、完成阶段 0x117800D0、magic 0x4D423138。上电期间没有持续观察，SRAM 上电值不确定，只能说自然上电后未获取到 V118 的有效执行证据，不能判定 CPU 从未执行，也不能从无标记断言 FIFO 状态。CLKEN=0与固件预期启用0x21不同，但不能排除启动入口、调试状态或写通道问题。

两个独立会话均初始报告 running，且各 halt 一次后报告 halted；前一会话没有显式 resume。这是需审计的调试状态差异，不能假定跨会话保持 halted。不得声称本轮 CPU store 已测试。

原始日志：runs_local_i2c_next/BBX_V123_POST_REPLUG_READONLY_20261110_01_20261110_184936_921307 和 runs_local_i2c_next/BBX_V123_FLASH_MAILBOX_READONLY_20261110_01_20261110_185017_823639。combined SHA256 分别为 5FE573946716E828E4CC02002915726AAE79867F721BC7988B2E8C3A3C5A22D2 和 9B9A71A049ABFD1E9BE9BDD8B48BAD0B5AD8B6CDCD88561D626F405961C14751。

下一步离线追踪现有 OpenOCD 退出行为、DMCONTROL 与参考 RTL 及启动地址，定位跨会话 running、V118 自然启动缺失。准备可识别且低副作用的 CPU canary，优先复用已有镜像/Flash，不在 PC/DPC 语义未厘清时盲目覆盖 Flash。只有本轮唯一标记被证明写入后，才能运行 CPU FIFO 对照；之后捕获 TX_NUM/WORK/DATA/错误并与 SBA 对照。
