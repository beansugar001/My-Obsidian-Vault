# V134 固定DMI写实现：DIR地址切离A/B

## 计划与安全边界
同一会话、同一显式DMI写实现、同一目标地址DIR=0x40000104、同一数据0x8。A写前最后访问DIR，不读其他MMIO；若A未确认，则B先读取ODR=0x40000100（安全读）再返回DIR写相同0x8。最多3次目标写，第3次用于通过切离方式恢复DIR=0。全程ODR=OSOD=0xC、AF=0，输出配置也为开漏释放，不发送SCL/SDA数据帧；无FIFO、I2C_EN、Flash/NVR/SRAM、reset/resume操作。

## 实物结果
- 初始DIR旧DMI与mdw各三次均0；前置CLKEN=1、RST=0、AF=0、ODR=0xC、OSOD=0xC。
- A_NO_PARK：一次DIR<-0x8，等待100ms；两读法各三次仍0，未确认写入。
- B_WITH_PARK：读取ODR=0xC后，以同一函数再写DIR<-0x8，等待100ms；两读法各三次为8，写入已由读回确认。
- RELEASE_TO_INPUT：读取ODR后写DIR<-0，再等待并交叉三次读取，均为0。
- 最终DIR=0、ODR=0xC、OSOD=0xC。本轮目标写3次，初始running、halt一次后报告halted；退出会话后的CPU/寄存器状态未再检查。
结果：A_FAILED_B_SUCCEEDED_PARK_CORRELATION。

## 支持的解释及不能证明的部分
V134固定写实现，消除了V132原生mww与V133显式DMI写的差异；重复出现“未切离不更新、切离后更新”，支持写前SBA地址/请求状态参与的候选。B还多出ODR读取所需的时间、DMI事务与读副作用，且次序为A后B，无随机化、无等时延控制，因此仍不能把地址边沿敏感或ASIC RTL缺陷定为唯一根因。mdw与旧读函数都经过同一DM/总线路径，非独立物理观测。

此证据使“临时地址0x50解锁I2C_EN”成为更弱的解释：此前该办法也改变了写前地址，可能属于总线写触发问题。必须后续用直接ADDR=0x3C、写前安全读取策略验证；不得先假定目标地址已经正确锁存。

## 后续具体方案
1. 修正GPIO ACK脚本：所有目标写之前先读取一个不同地址的安全寄存器，白名单限制GPIO_DIR/ODR/OSOD；保持PUPD=0x300、I2C时钟关。读回每个GPIO配置，任一不符停止并用受控开漏释放收尾。
2. 拉低用ODR=0+DIR输出，释放用DIR输入；第九拍必须DIR=0、SDA输入，从IDR采ACK。只发一个0x78地址帧，先不发送OLED命令。旧V112输出模式NACK维持未验证。
3. 若该帧与方向控制通过，再规划I2C初始化中每笔写前的地址切离策略；不先使用临时地址0x50。只能根据全新空闲前置条件决定是否执行，FIFO卡住时不追加数据。

## 交付
原始目录 `runs_local_v109/BBX_V134_DIR_ADDRESS_AB_20261110_01_20261110_203638_249562`，combined SHA256 `068C3F5E1B025109F26B35A9E61A7D9B6B1A59113F9471EBEC09358A7EDC0D8C`。脚本 `03_experiments/v134_dir_address_ab.tcl`，包装器 `run_v134_dir_address_ab.py`，已固定Tcl SHA。历史marker和日志保留。
