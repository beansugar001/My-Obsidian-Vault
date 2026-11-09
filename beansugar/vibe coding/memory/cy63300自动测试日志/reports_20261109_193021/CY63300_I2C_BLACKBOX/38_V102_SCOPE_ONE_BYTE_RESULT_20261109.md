# V102：重插后的示波器单字节探测

日期：2026-11-09（Asia/Shanghai）

重插后使用全新 V102 阶段。V102A/B 开启 I²C/GPIO 时钟，最终 CLKEN=`0x21`、RST=0；V102C 将 Pad8/SCL、Pad9/SDA 配为 AF3、开漏、上拉和释放，IDR=`0x2C`；V102D 按 ARM 顺序初始化，DIV0/1=`0x3E7`、MODULE=`0x0F`、FIFO=`0x05`、ADDR=`0x3C`、STA/RAW=0。配置阶段均读回通过。

V102E 入队一个 `0x00` 并在有限等待后发出一次 STOP。40 轮观察为 `TX_NUM=1`、`STA=1`、`RAW=0`、`DATA_seen=0`；STOP 后 FIFO=`0x104`、WORK=1 仍不变。最终结果 `FAIL_OR_UNKNOWN`、`FRAME_COMPLETE=0`、SBCS=`0x20040404`、DMSTATUS=`0x00430382`。本次目标写共 14 次（时钟 2、Pad 5、控制器 5、FIFO 1、STOP 1），无 reset/resume/Flash/NVR/重试。

日志 SHA256：

| 阶段 | SHA256 |
|---|---|
| V102A | `1740980C07DCCB61186795433DFBA07EA1F88B44F79FC46EAFB7D3849FF79A7F` |
| V102B | `174B806F2ADD17EAF4A96B8D35004E706808AC966739A53BCF2663D638F83D34` |
| V102C | `8D97BD857F7DC640D1DEF52379FDAB47F9730CC84543428DF8C1BCFAF6FE8D25` |
| V102D | `CB545952DE69B5C8822D81F0530A293BB94D9D4D42CFA89153516DC7D13527B1` |
| V102E | `63C036D5EC95FC3140B5178F36BE57608C84540A98EF704FB822476BBF7FFA38` |

用户报告：本轮 Single 没有冻结，屏幕上没有看到脉冲。该观察与 TX_NUM=1/WORK=1/DATA_seen=0 一致，支持“控制器未推进到 SCL 时钟输出”的判断；但因没有示波器照片/设置读数，尚不能排除触发源或探头接触导致的漏捕获，也不能据此判断 SDA 上是否有极短 START。

V102E 后不得追加 I²C 写入；先断电清除挂起状态。下一项区分性测试应改为 GPIO 直接让 Pad8/SCL 产生一个慢速、可见的低—释放脉冲（不启用 I²C、不写 FIFO）：若示波器能捕获，则探头/Pad8 输出链路基本成立，故障进一步收窄到 I²C AF/START/主状态机；若仍无波形，则先查探头连接、Pad8 映射或 GPIO 输出链路。执行该 GPIO 脉冲前仍需重新完整掉电，以解除本次控制器挂起，并另用新阶段 marker。
