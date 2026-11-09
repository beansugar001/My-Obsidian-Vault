# V5.8：V4.4与V5.7访问时序审计

结论：确有脚本时序差异，但不能认定“读SBCS取消写入”。V4.4日志证明DIV0=20→21→20；V5.7请求写21后两次读回20，最终失败停止。

| 项目 | V4.4 | V5.7 |
|---|---|---|
| 入口 | adapter_khz 100; init; halt | 相同 |
| 运行配置 | 同名tinyriscv_10k_clean.cfg | 同名配置 |
| 探针序列号 | 07000001006700343500000a4e57354aa5a5a5a597969908 | 相同 |
| IDCODE / DMSTATUS | 1E200A6F / 00430382 | 相同 |
| misa（异常独立记录） | 4C80480A | FFFFFFFF |
| 写前时钟 / 复位 / CTRL | 20 / 00 / 02 | 20 / 00 / 02 |
| 写前DIV0两次 / DIV1 | 20、20 / 30 | 相同 |
| FIFO状态前置采样 | 本阶段未记录 | 05 |
| 设置写模式 | DMI W38=20040404 → R38检查 | 相同 |
| 地址、数据 | W39=40002810 → W3C=21 | 相同 |
| 数据命令返回后 | sleep 100ms | R38检查busy/error → sleep 100ms |
| 等待后的首个目标读 | PERI_CLKEN（随后sleep80ms和更多系统状态） | PERI_CLKEN（读完6个字段后sleep100ms再读4字段） |
| 所有目标读 | W38=20140404 → R38 → W39=地址 → R3C → R38 → W38=20040404 → R38 | 相同 |
| 读地址触发后等待busy解除 | 没有先R38即R3C | 相同；AFTER_READ检查滞后于R3C |
| 写后首个SBCS读 | 100ms后，第一次读模式设置后的R38 | 数据写命令后立即R38，仍为写模式 |
| 结束 | W38=20040404 → R38 → W39=0 | 相同（V57失败路径仍做此调试配置清理） |
| 恢复机制 | 原PS脚本finally自动启恢复/关时钟等独立连接 | 阶段独立，一次标记；本次失败无恢复写 |

以上展开序列来自实际Tcl在离线命令stub中的执行，分别保存于v44_expanded_trace.json、v57_expanded_trace.json。stub提供正常寄存器返回值，仅用于展开分支和sleep时长，不能作为硬件成功证据。实物日志没有每条DMI时间戳，因此USB耗时、实际DMI间隔、系统时钟周期、SBA真实完成时间均未知。没有为了验证假设重放历史脚本到硬件。

当前工具和配置SHA256见config/policy.json；历史未保存对应二进制/配置哈希，无法证明两个实验当时使用的字节完全相同。相同名称、banner或当前哈希不能补造历史哈希。

## 标准与参考实现差异

依据[RISC-V Debug 0.13.2，§3.12与§3.12.1，SBCS表](https://riscv.org/wp-content/uploads/2019/03/riscv-debug-release.pdf)和[官方寄存器定义](https://github.com/riscv/riscv-debug-spec/blob/main/xml/dm_registers.xml)：

- sbversion[31:29]、sbbusy[21]和能力字段为只读；sbbusyerror[22]、sberror[14:12]为写1清除。纯读SBCS不应清除错误或启动目标写入；busy时写SBCS行为未定义。
- sbreadonaddr[20]使写SBADDRESS0触发目标读取；sbaccess[19:17]=2为32位；sbautoincrement[16]、sbreadondata[15]决定后续访问行为。
- 20040404解码：version1、32位访问、32位地址、支持32位；无忙/错、无自动读/递增。20140404仅多置bit20。00607000掩码覆盖busyerror、busy、sberror，不覆盖所有协议问题。
- 两魔数包含RO能力位；标准设备应忽略其写入，不能要求全字读回等于写值作为通用驱动。本地参考DM却直接sbcs<=data，既没有真实busy，也没有桥接完成错误反馈。SBCS无错误不能证明目标写提交。

本地原始DM在SBCS读取分支只复制sbcs到read_data，没有取消待写的独立逻辑；但原版写使能本身只维持短脉冲，任何后续串行DMI等待都不能恢复已经丢失的写。新增加的状态读取会改变系统经过的时间和请求模式；在未知ASIC中是否造成差异仍是待验证假设。

## 验证优先级

1. 离线保持相同竞争条件，对比写后立即SBCS读与增加延迟，再核对真实RAM提交数。
2. 分离“读SBCS”与“写SBCS切换模式”；后者在busy时具有规范明确限制。
3. 索取ASIC的DMI/SBA、互联和目标寄存器实现及真实完成握手。历史misa异常作为独立读稳定性问题，不直接归因I²C。
