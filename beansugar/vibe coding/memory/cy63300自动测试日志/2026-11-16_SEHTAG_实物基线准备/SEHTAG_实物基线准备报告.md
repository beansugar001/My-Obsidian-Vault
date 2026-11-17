# CY63300 SEHTAG 实物基线准备

日期 2026-11-16。审查 Repo_Fanglongrui 提交 189fff578a44b61a328af08e32e60ac890b19a91。只进行本地源码检查、模块仿真和对象编译。

## 已验证

- Icarus Verilog 12.0 对仓库 csr_reg.v 仿真。公开 RTL 的 CSR_SAFETY_CTRL 为 0x803，bit 0 控制安全检查。测试台测得复位读零、检查关闭，向该 CSR 写 1 后读回 1，检查打开。该结果仅适用于所审查的 RTL。
- 同一份合法分配包装函数用本机 xPack GCC 8.3.0 编译。默认占位路径生成对象文件。原生路径报汇编器不认识 halloc，未生成原生可执行镜像。
- 实验仓库通用 BSP 把镜像链接到 0x80000000，默认平台日志和结果接口为空实现。已验证的 CY63300 裸机 V159 从 Flash 0x00000000 启动，设计文档的 SRAM 地址为 0x20000000–0x2001FFFF。通用 ELF 直接烧录无法作为本板验收。

## 实物基线所需资料

1. 样片型号及版本对应的 SEHTAG CSR 说明，保护初始化顺序，实际异常码与结果输出方式。公开 RTL 的 CSR 编号目前只作比对。
2. 对应的汇编工具链，或一份已在同版 CY63300 上运行过的最小诊断 ELF/BIN、链接地址和操作说明。
3. 首轮固件只记录启动、保护初始化、一个有效对象的合法写入和读回，以及独有完成标记。上板前用已验证的 Flash/SRAM 布局核对镜像并确认恢复路径。当前未接设备、未运行硬件、未写 Flash。

run.ps1 为复现入口，csr_enable.log、csr_enable.vcd、compiler_version.log、native_compile.log、result.json 为原始记录。
