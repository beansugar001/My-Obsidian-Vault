# 2026-11-21 CY63300 栈对象登记与「开检查后阶段」— 目录索引

本轮目标（用户 m00795）：确认样片上的**栈对象登记状态**、定位**开启安全检查后程序停在哪一阶段**。要求先只读核对 + 反汇编审查 + 参考仿真，再给可执行板测方案；换固件前必须先报改动/差异/判据并等确认（m00358）。**本轮没有烧录、没有对样片内存做任何写入。**

## 目录

| 目录/文件 | 内容 | 结论来源 |
|---|---|---|
| `snapshot_20261121_103951_readonly\` | **有效**只读快照：main.tcl、openocd.log、flash.bin(1024B)、mbox.bin(68B)、res.bin(28B)、frame.bin(32B)、plm.bin(16B)、snapshot.json。全部 dump 在 shutdown 之前 | 样片实物 |
| `snapshot_20261121_103359\` | 10:33 的只读快照（同一镜像，读数与 10:39 逐字相同；res.bin 只有前 7 字） | 样片实物 |
| `snapshot_20261121_103934_readonly\` | 失败的一版脚本（tmp.bin 0 字节），仅留档 | — |
| `rtl_reg_sim\` | 参考 RTL 登记链验证：firmware_reg.S、firmware_reg.bin/hex、firmware_reg_disasm.log、tb_stack_reg.sv、build_and_sim.ps1、mkhex.py、sim_reg.log（复跑输出） | 参考 RTL 仿真（提交 189fff5） |
| `v2b\` | 待批准的诊断镜像：firmware.bin(480 B, sha 8407D655…53FE)、firmware.hex、firmware_disasm.log、firmware_v2b.S、tb_stack_v2.sv、build_and_sim.ps1、sim_v2b.log（参考 RTL 预期值） | 参考 RTL 仿真（**未上板**） |
| `第1项续_栈对象登记与开检查后阶段_20261121.md` | 本轮权威报告（四行交付表、v2b 改动与判读矩阵、复现命令） | 汇总 |
| `probe_snapshot3.py` | 只读快照脚本 | — |

## 本轮结论（一句话）

样片这份 436 B 镜像**没有登记任何对象**（反汇编无 WRPLM/LDBNB/WRTAG，PLM 0x7000_0000 直读全 0）；开启 `safety_check_en`（CSR 0x803 bit0）之后**最后一个可确认阶段是 F 段完成标记 0x4D533141 写入**，之后的 0x118 那笔 store 之后再无 CPU 自写标记，「挂住」与「进了异常但清不掉使能导致递归陷阱」目前分不开 → 区分证据 = v2b 的 M1/M2/M3。

## 关键读数（样片，10:39 只读）

- 镜像 Flash 前 436 B，sha256 `4451545F0678DA0546176F27C4659D2FF94DAA54FC691EA4676328565EA584CC`；指纹 0x100=`0x14128293`、0x1AC=`0x005D2823`。
- mbox w0..w15 = 4D533141, 2001FF00, 2001FEE0, 11112222, 33334444, 0, 13579BDF, 2468ACE0, 13579BDF, 2468ACE0, 1, 13579BDF, 2468ACE0, 1, 13579BDF, 2468ACE0。
- 结果块 r0..r6 = 1, 1, 7567DD43, EF5723D1, E2DF81B2, DE94C994, 37DD9E97（r2..r6 来源不明，不作结论）。
- frame = 11112222, 33334444, BF90628B, 464434E9, 13579BDF, 2468ACE0, 9772480D, 000000E0。
- PLM 0x7000_0000..0x0F = 全 0。

## 参考 RTL 新增发现（只适用于参考 RTL，不可外推）

`rtl/core/bnbcache.v:326-356` 的 `check_valid_o` 是寄存器输出，索引取 ID 级 rs1、地址取 EX 级 → 判定错开一拍，实际用**下一条指令的 rs1** 索引对象：后继 rs1 无条目时越界 store 被放行并提交；后继 rs1 是另一个带标签指针时合法 store 被误报；判定失败也可能先提交再抛异常；该异常恒不写 mepc。仓库 `rtl/perips/plm.v` 是 4 字桩，只有 pointer id 0/1 可用。

## 下一步

v2b（480 B）把 G 段改成「开→关→M1→开→测试 store→关→M2→0x4D533143→自旋」，陷阱入口先写 M3。判读矩阵与烧录/回滚流程见报告第 3 节。**烧录需用户确认。**
