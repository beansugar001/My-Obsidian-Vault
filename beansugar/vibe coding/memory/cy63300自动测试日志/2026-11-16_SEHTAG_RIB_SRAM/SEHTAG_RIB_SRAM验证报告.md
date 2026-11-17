# SEHTAG 访存保护 RIB 与 SRAM 验证

日期 2026-11-16。使用 Icarus Verilog 12.0，源代码来自 Repo_Fanglongrui 提交 189fff578a44b61a328af08e32e60ac890b19a91。使用仓库的 tinyriscv、rib 和 ram 模块。厂商仓库未修改。未连接物理芯片。

## RTL 仿真结果

测试台向 CPU 提供已经稳定的许可结果，其他总线主机保持空闲。通过时钟沿上的 ram 写使能次数、ram 内部数据以及 CSR mcause 确认结果。

- 允许时三处信号同时有效，CPU 访存请求、CPU 写使能、SRAM 写使能。SRAM 在验收窗口提交一次，数据更新，mcause 为 0。
- 拒绝时三处信号均为 0，SRAM 写入次数无增加、数据保持原样，mcause 寄存器为 0x5。
- 两项通过。范围是已确定的检查结果如何经 CPU 顶层与 RIB 传递到 SRAM。测试台使用抽象的许可输入；真实 BnBCache 判定产生的周期和多主机仲裁未纳入本轮。

## 源码复核和待确认事项

- bnbcache.v 第 326 行起按时钟上升沿更新 check_valid_o。
- ex.v 第 236–237 行组合控制 mem_we_o 与 mem_req_o。tinyriscv.v 第 466–476 行选出 CPU 总线请求。
- rib.v 第 123 行起组合仲裁，第 175 行起转发到 SRAM。perips/ram.v 第 23 行起在时钟上升沿采样写使能。
- 当前检查结果接口只见 check_en 和 check_valid。已审查的路径尚未找到能证明该结果与本笔请求对应、且在 SRAM 首次提交之前稳定有效的独立握手。源码观察是待核时序事项。本轮结果不判定流片芯片行为。

请 RTL 作者提供保护参与的访存事务时序图或既有波形，注明请求发出、判定有效与 SRAM 采样对应的周期，并确认仓库提交与手头样片的关系。验收需要能在波形中确认，判定待定期间零提交，允许后只提交一次，拒绝时零提交且记录异常。

## 复核材料

run.ps1 可重现仿真。run.log 保存断言结果，compile_args.json 保存完整参数，rib_ram_decision.vcd 保存波形。
