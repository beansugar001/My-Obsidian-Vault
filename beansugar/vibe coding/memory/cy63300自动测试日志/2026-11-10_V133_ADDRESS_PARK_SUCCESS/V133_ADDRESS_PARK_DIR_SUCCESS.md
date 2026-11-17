# V133 地址切离后返回：DIR单次清零成功

## 本轮规划与预算
确认时钟GPIO-only=1、RST=0、AF=0、OSOD=0xC、ODR=0xC（输出释放），旧DMI读法与原生mdw三次均DIR=8。读取其他安全寄存器ODR 0x40000100，确保SBA地址切离DIR；再设置SBA写模式、地址DIR 0x40000104，只向SBDATA0写0一次，等待100ms，交叉读回。无I2C/FIFO/Flash/NVR/SRAM写、无reset/resume。新marker独占，未复用旧记录。

## 实物结果
写前 old/native：8/8、8/8、8/8。
读ODR=0xC后，地址返回DIR、单次SBDATA0写0。
写后 old/native：0/0、0/0、0/0。
最终DIR=0、ODR=0xC、OSOD=0xC；PERI_CLKEN=1、RST=0为前置读数，未修改。目标MMIO写1次，CPU initial running且单次halt后报告halted，退出会话后的状态未再次观测。
结果 DIR_CLEAR_AFTER_ADDRESS_PARK_CONFIRMED；combined SHA256 `5AB653F8C1581809995A3893D65FFCBB44A127EC7C3F05808AFD8D9E80C0068E`。

## 与失败记录的差异及证据强度
- V131：旧显式DMI写DIR，连续同地址操作从8写C失败，清0也读8。
- V132：写前最后访问DIR，原生mww清0一次，读后仍8。
- V133：写前特意读ODR切离目标地址，再显式DMI返回DIR写0，一次成功。

支持“写前SBA地址/访问状态参与触发”的候选。不能直接称确定的地址边沿缺陷：V132与V133除了插入ODR读取，还有原生mww与显式DMI写实现差异、会话初始状态/时序差异；需要固定同一写实现的后续对照。旧V131显式DMI写失败则为另一支持证据，但也非严格同步A/B。

## 对历史I2C解释的影响
V126/V128 原ARM次序在读取MODULE_CTRL后立即向同地址写I2C_EN失败；改临时ADDR、再写MODULE_CTRL、再写最终ADDR则成功。V133提示此前被解释为地址锁存/初始化顺序的表现，也可能与SBA写请求重新触发/地址变化有关。不得再断言0x50是芯片使能的必要条件。FIFO本身仍未证实恢复，不应把本次GPIO成功写成I2C成功。

## 下一步方案（本轮没有继续硬件写）
1. 为GPIO写辅助函数加入明确的写前安全地址读，并固定SBA idle/read/write模式与独立读回；所有目标写仍逐笔白名单、计数、失败停。
2. 先做无I2C数据的固定实现方向寄存器对照，隔离地址切离是否必要；每次只变化读停车位置。
3. 确认GPIO方向可连续控制后，再用SDA输入采样修正后的单帧0x78 ACK探测。历史V112输出模式ACK/NACK结论维持未验证。
4. 若可重复证实地址切离策略有效，再新上电核对I2C使能是否可在直接ADDR=0x3C时成功，不使用临时0x50；再进行单字节FIFO测试。不要跳过空闲条件或向当前活动FIFO追加数据。

## 当前清单更新
- DIR双读法清零（V132）：已做未确认。
- 地址切离后DIR清零（V133）：已做成功，单次可复核。
- 根因严格A/B及跨寄存器复现：未完成。
- GPIO正确输入ACK、I2C FIFO排空、OLED显示：仍未完成。

原始日志：runs_local_v109/BBX_V133_DIR_ADDRESS_PARK_20261110_01_20261110_203305_676490。脚本03_experiments/v133_dir_address_park.tcl，包装器run_v133_dir_address_park.py；SHA固定及历史marker保留。
