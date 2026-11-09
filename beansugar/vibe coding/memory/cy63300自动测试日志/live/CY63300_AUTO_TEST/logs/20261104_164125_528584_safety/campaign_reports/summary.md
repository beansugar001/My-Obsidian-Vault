# CY63300本轮进度与结论

**总体状态：BLOCKED。** 已完成历史审计、参考RTL扩展仿真、受控框架和一次连接级只读检查；尚未恢复或验收实芯片I²C。目标MMIO/Flash/NVR/OTP写入均为0。

| 阶段 | 状态 | 实际结果 |
|---|---|---|
| 文件与历史审计 | PASS | 583份文件哈希清单；71份输入/历史脚本、日志、marker等快照 |
| V4.4↔V5.7时序对比 | PASS | 写后立即R38有差别；历史工具哈希缺失，因果未证实 |
| 原始/候选编译与诊断运行 | PASS | 两版完整结束；保留六项原有检查，新增九项 |
| 原版新增功能不变量 | FAIL | 2/9通过，7/9失败，竞争时可0提交却SUCCESS |
| 候选新增功能不变量 | FAIL | 6/9通过，3/9失败：目标拒收两项、连续请求两提交一响应 |
| 框架mock | PASS | 28项；失败停止、预算、白名单、解析与日志保留 |
| 本轮硬件预检 | FAIL | 实际识别正确TAP/DM；脚本重复输出误判多TAP，未进入目标寄存器采样 |
| 当前六目标寄存器状态 | NOT_TESTED | 历史基线不能代替当前读数 |
| 新MMIO写/恢复阶段 | BLOCKED | 未取得本阶段独立授权，且完整预检未通过 |
| 实物I²C事务 | NOT_TESTED | 无本轮START/ACK/收发/STOP或总线释放证据 |

参考模型中，立即读SBCS与等待50周期后读的结果相同：有竞争时原版均丢写，候选均提交一次。**本轮没有支持“纯读SBCS取消写入”的证据**，也不能排除未知ASIC实现差异。

当前硬件直接读出ID=1E200A6F，DMSTATUS=00430382，SBCS=20040404，misa=4C80680A；100kHz，探针序列号07000001006700343500000a4e57354aa5a5a5a597969908。misa与历史不同仍须单列调查，不能因ID正确就认为全部调试读可靠。

一次预检失败来源是本轮框架：capture(init)已记录日志，我又echo了一遍，主机检查误认为两个TAP。已离线删除重复输出，28项检查通过；原始失败记录与marker保留，**修正版没有实物重跑，也未绕过marker**。

下一步：先审查并单独安排新的完整只读预检，确认六寄存器基线和CSR异常；通过后，再考虑单次DIV0=20→21。精确方案在next_write_plan.json、risk_and_recovery.md；恢复20是再次授权的独立阶段。尚无可直接运行的真实写入口。

证据入口：

- v58_timing_diff.md / timing_diff.md：逐项时序与SBCS规范。
- v59_sba_rib_report.md / v59_results.json：逐用例计数、失效与边界。
- failure_analysis.md：根因候选、反证、置信限制、下一项。
- source_audit.md：参考连接与源码位置；不等同ASIC。
- i2c_stage_plan.md：初始化与真实通信验收计划。
- register_snapshots.csv：历史实际读数、本次DMI读数、未测目标地址。

本轮实际离线执行目录：C:\Users\24796\Documents\组\CY63300_AUTO_TEST\logs\20261104_163909_238323

本轮实际硬件日志：C:\Users\24796\Documents\组\CY63300_AUTO_TEST\logs\20261104_163943_200538

最新离线安全检查：C:\Users\24796\Documents\组\CY63300_AUTO_TEST\logs\20261104_164125_528584_safety

运行完成与功能正确分别统计；BLOCKED/NOT_TESTED不计为PASS。当前未取得实际ASIC RTL、原始ARM驱动或本轮仪器采集，不能宣称芯片已修复。
