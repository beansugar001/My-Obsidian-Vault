# V99：重插后恢复 I²C 空闲配置并进行示波器单字节探测

日期：2026-11-09（Asia/Shanghai）  
目的：在示波器探头已接到 SCL/SDA 后，重建已验证的 ARM 顺序控制器配置，并用一次最小 FIFO 字节观察真实总线。

## 结果摘要

- V98 重插后只读结果为 `PERI_CLKEN=0`、`PERI_RST=0`。V99A 按 V92G 已验证顺序读取时钟关闭诊断值后，单次写 `PERI_CLKEN=0x20` 成功读回；V99B 单次改为 `0x21`，GPIO/I²C 时钟均开启。
- V99C 重新配置 Pad8/SCL 与 Pad9/SDA：AF3、开漏、上拉、释放；IDR=`0x2C`，两条线在静态输入采样中为高。
- V99D 按 ARM 初始化顺序设置 DIV0/DIV1=`0x3E7`、FIFO、7-bit 地址 `0x3C`、最后使能 I²C。结果 `MODULE_CTRL=0x0F`、FIFO 空、STA/RAW=0、IDR=`0x2C`。
- V99E 只写一个 TX FIFO 字节 `0x00`，有限轮询后按 ARM 超时路径只发一次 STOP。FIFO 仍有 1 字节、WORK=1、DATA_seen=0；STOP 后仍未回到 idle。结果 `FAIL_OR_UNKNOWN`，`FRAME_COMPLETE=0`。
- **这次运行没有读取示波器画面或波形文件，因此不能声称 SCL/SDA 有脉冲，也不能判定 OLED ACK/NACK。** 寄存器状态只表明控制器没有推进。
- 当前 I²C 状态再次挂起。V99 后没有复位、resume、再次写入或断电；不要追加 FIFO/STOP 写入。先保存示波器 Single 捕获画面，再整板断电重插并做只读恢复检查。

## 各阶段证据

| 阶段 | 实际结果 | 目标写入数 | 原始日志 SHA256 |
|---|---|---:|---|
| V99A 时钟 | CLKEN=`0x20`、RST=0、SBCS=`0x20040404` | 1 | `C471B309CE596400D6B4AE6CEDDF7A9B1FB7568C4E319A15940132CDED935650` |
| V99B GPIO 时钟 | CLKEN=`0x21`、RST=0、SBCS=`0x20040404` | 1 | `48146643CF91E68B97A2862C4ACF0A174A4C4F3637311281E0C6BC78527528CA` |
| V99C Pad | IDR=`0x2C`；AFR1=`0x6C0`；SBCS/DMSTATUS正常 | 5 | `B270602E1FBC8B9A28C4900CD22481501CB8A4C418F170B20E71F7395910DB3B` |
| V99D 控制器 | DIV0/1=`0x3E7`；MODULE=`0x0F`；FIFO=`0x05`；ADDR=`0x3C`；STA/RAW=0 | 5 | `D2E86849898916E5CA98BEE3AE0696671E90080268F22BFF65E9F3545C7BBC6E` |
| V99E 单字节 | FIFO=`0x104`，TX_NUM=1；STA=1；RAW=0；STOP 后仍相同；SBCS=`0x20040404` | 2 | `F650992846F1A67B410171BC87C9CAC9DA3E5981D3A656F25239C18D7B945513` |

## V99E 单字节事务细节

事务前：`CLKEN=0x21`、`RST=0`、`MODULE=0x0F`、`FIFO=0x05`、`DIV0=DIV1=0x3E7`、`MODE=1`、`ADDR=0x3C`、`MCTR=0`、`HOLD=5`、`STA=RAW=0`；Pad8/9 的 AF、开漏、上拉配置及静态高电平检查均通过。

目标写入只有：

1. `0x40002808 <- 0x00000000`：向 TX FIFO 放入一个字节。
2. 超时后 `0x40002828 <- 0x00000002`：一次 STOP 请求。

40 次发送前样本和 40 次 STOP 后样本均显示 FIFO=`0x104`、TX_NUM=1、STA=`0x01`、RAW=0、DATA_seen=0。最终 DMSTATUS=`0x00430382`、SBCS=`0x20040404`。这只能说明调试/SBA 本身没有报告错误，不能说明物理线上出现了波形或地址 ACK。

## 下一步

先记录示波器捕获：CH1/H4-8 是否有 SCL 脉冲；CH2/H4-9 是否有 START；地址字节后第 9 个时钟 SDA 是否拉低（ACK）；数据字节后是否有 ACK/STOP。若捕获未冻结或没有图像，说明波形证据缺失，不等同于“没有脉冲”。本次 FIFO 状态卡住，不再执行第二次 I²C 事务；取得画面后断电重插清状态，再单独规划下一次实验。

执行入口：`run_v99_scope_oled_probe_once.py`。五个独立 marker 与运行目录均在 `markers/`、`runs/`，历史 V97B 证据保留未覆盖。
