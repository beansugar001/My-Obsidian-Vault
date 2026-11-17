# SEHTAG RTL 自然启动与合法分配验证

2026-11-16。仓库 Repo_Fanglongrui 提交 189fff578a44b61a328af08e32e60ac890b19a91。使用 xPack RISC-V GCC 8.3.0 和 Icarus Verilog 12.0。只做离线仿真。

## 两项实测

- 完整 tinyriscv 核从复位地址 0 自然取指执行 72 字节仿真镜像。固件以普通 CSR 指令读、使能、再读公开 RTL 的安全开关。读回从 0 到 1，检查信号为 1，mcause 为 0，通用寄存器完成标记为 0x60。无访存请求，无测试台 force。
- 独立 mcu_memory_security 模块通过其正常接口收到一个合法 32 字节对象的分配请求，返回 valid、地址 0x20000000，无 error。该请求由测试台直接驱动，未经过 CPU 指令，未验证对象内写入和读回。

## 公开源码的集成差异

独立 mcu_security_system.v 用 memory_security_instruction_handler 驱动 HAT；公开 tinyriscv.v 第 1272–1276 行将该 HAT 的操作入口固定为零，保留独立的查询入口。通用实验固件用 halloc 助记符，但本轮未在 CPU 译码到 HAT 的公开路径中找到对应接线。因此，单独编出指令不能补足 CPU 顶层的分配通路。真实样片是否使用不同实现仍待确认。

## 后续

完整 CPU 的原生合法分配和受保护读写尚未完成。若继续用公开 RTL，建议另建隔离仿真集成版本，明确指令译码、返回值写回与分配完成握手，同时保留公开基线用于比较。若转入实物，先核对映射和启用方式，当前镜像只用于仿真。

run.ps1 可重现。boot_tb.run.log、hat_tb.run.log 和对应 VCD 保存原始证据。

