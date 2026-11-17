# V132 GPIO DIR清零：交叉读法与单次写入

## 计划/实际边界
对V131停在DIR=8的现场做新独立实验。ODR=0xC、OSOD=0xC，PB2/3开漏数据释放；GPIO_AF=0、CLKEN=1、RST=0。旧直接DMI SBA读法与OpenOCD原生mdw交叉读各三次。若一致且DIR=8，允许单次原生mww 0x40000104 0，再等待100ms交叉读各三次；不发I2C字节，不写FIFO/Flash/NVR/SRAM，不reset/resume，不自动重试。

## 真实结果
JTAG/DM前置检查通过，CPU初始running，单次halt后报告halted。写前旧读法/原生mdw均三次DIR=0x8；单次mww写0后，两者仍三次DIR=0x8。最后ODR=0xC、OSOD=0xC、DIR=0x8。结果DIR_CLEAR_NOT_CONFIRMED。目标MMIO写1次，期间无异常连接或SBA错误日志。最终SBCS=0x00150000（1376256），包含原生读事务配置，不应仅要求等于0x20040404才正常；检查busy/error位。

## 结论边界
本轮清零未获读回确认，不只是旧v115e_rd独自返回旧值。mww/mdw仍经同一DM及目标总线，非独立物理观测，不能宣称两个独立硬件通道都失败，更不能凭此认定GPIO损坏。未能证明写事务在GPIO寄存器处提交。ODR释放值读回维持0xC，不代表示波器证实线高。当前仍未完成可信GPIO ACK帧。

## 手册/源码复核
数字手册 GPIO_DIR 可写，每位方向0输入1输出。IDR 输入读信号、输出读数据寄存器。OSOD[5:0]开漏位、[11:6]开源位，因此PB2/3 OSOD=0xC；PUPD[11:6]为上拉位，PB2/3=0x300，配置位含义没有发现应改成其他值的依据。

## 状态与后续
- 已完成：DIR旧DMI读与原生mdw交叉；单次原生mww清0及延迟读回。
- 未完成：可靠清DIR、修正后的GPIO ACK、CPU store FIFO对照、OLED通信。
- 下一阶段候选：离线逐笔比较V130（DIR=0时可改变ODR）与V131（DIR写8成功、后续C/0失败）的SBA序列，关注目标写提交及GPIO方向寄存器更新条件；如设计允许，可规划先在输入释放条件下更换一次已证实的DMI写序列作为单变量对照。不得沿用本阶段marker重复清零，也不把额外FIFO/STOP当恢复手段。

日志目录 runs_local_v109/BBX_V132_DIR_CROSSCHECK_20261110_01_20261110_202944_063554；combined SHA256 7C2F6BC0D5B71830DA315089902B6CD32FA5DBA4A7743DD498729B24B068EB09。历史marker保留，退出会话后的CPU与外设状态未重新观测。
