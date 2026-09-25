# 2026-09-25 autoccfa RISC-V侧信道CCFA论文

# 用户偏好

- **语言**: 始终使用中文回答
- **包安装规则**: Python包装到 `D:\pythonpackage\py312-packages`（pip --target），或用 conda 环境
- **代码风格**: 脚本可复现，路径全部用绝对路径
- **数据铁律**: 论文中所有数字必须来自真实运行，禁止编造

# 当前项目：autoccfa（RISC-V 微架构侧信道 CCF-A 论文）

## 项目配置

- **项目根目录**: `D:\project\autoccfa`
- **目录结构**: `docs/ lit/ code/ data/ experiments/ figures/ paper/ scripts/ logs/`
- **Python 3.12 主环境**: `D:/Anaconda2024/python.exe`，需要 `PYTHONPATH=D:/pythonpackage/py312-packages`
  - 已有包: numpy 1.26.4, pandas 2.2.2, sklearn 1.4.2, matplotlib 3.8.4, scipy 1.13.1, seaborn 0.13.2, pyverilog 1.3.0, neo4j 6.2.0
- **深度学习环境**: `C:/Users/24796/.conda/envs/thesis/python.exe` — torch 2.5.1+cu121, CUDA 可用 (GTX 1650 4GB)
- **Linux 实验环境**: Docker Desktop 29.2.1（WSL2 后端，daemon 需手动启动：`"/c/Program Files/Docker/Docker/Docker Desktop.exe" &`）
  - WSL 仅有 docker-desktop 发行版，无 Ubuntu
- **LaTeX**: 本机无 pdflatex/tectonic → 计划安装 tectonic（单二进制）
- **磁盘**: D 盘剩 61G
- **硬件约束**: GTX 1650 4GB，无 LLM API（方法不得依赖 LLM 调用）

## 当前进度

1. ✅ 读完三份方法论（Sibyl 19阶段 / 科研项目管理 / md-to-latex-converter）
2. ✅ 确认方向: RISC-V 芯片安全 → 微架构侧信道；投稿目标调研后定
3. ✅ 环境审计: Python包/Docker/WSL/LaTeX/GPU 盘点完成
4. ✅ gem5 v24.1.0.0 源码获取（容器内克隆，Windows克隆有CRLF污染shebang问题）
5. ⏳ gem5 RISCV gem5.opt 编译中（容器 `gem5build`，detached scons，日志 `D:\project\autoccfa\logs\build_log2.txt`）
6. ✅ RISC-V工具链 riscv64-unknown-elf-gcc 13.2.0 容器内就绪
7. ✅ 冒烟测试代码: `D:\project\autoccfa\code\smoke\smoke.c`（已编译过）+ `run_se.py`（O3+cache SE配置）
8. ✅ 攻击侧文献侦察完成 → `D:\project\autoccfa\lit\01_attack_landscape.md`（22卡片+拥挤区+gap清单）
9. ⏳ 防御/检测侧文献侦察（后台agent运行中）
10. ⏸ 选题决策 / 平台搭建 / 主实验 / 消融 / 绘图 / 写作 / LaTeX / 归档

## 决策记录

### 关键事实记录（选题依据）

- **DAC 2027 截稿: 2026-11-17 AoE**（距今约7.5周），会议2027-07 加州 San Jose → 定为初步主投稿目标
- gem5 v24.1 **O3+RVV 支持**: release notes #1711 修复了向量指令投机执行断言 → O3+RVV+投机被官方支持
- gem5 v24.1 **索引向量访存（硬件gather）完整实现**: `VlIndexOp::vluxei8/16/32/64_v`（`src/arch/riscv/isa/decoder.isa:705/796/887/978`）
- gem5 RISC-V `rdcycle` 返回真实模拟周期 `curCycle()`，默认启用（`src/arch/riscv/isa.cc:428`）；`rdtime` 是秒级墙钟（无用）
- 领先候选 Idea A: **RVV矢量扩展时序侧信道系统刻画 + RISC-V HPM/ML可检性**（工作稿 `D:\project\autoccfa\docs\02_idea_candidates.md`，规格书 `D:\project\autoccfa\docs\spec.md`）

### [2026-09-26] gem5 -j14 编译把 WSL2 VM 压崩（OOM）✅

**问题**: Docker Desktop 的 WSL2 VM 默认只分配宿主 50% 内存（16GB→8GB），`scons -j14` 多个 g++ 各占 1-1.5GB → OOM，daemon 500 失联
**解决**: 新建 `C:\Users\24796\.wslconfig`（memory=12GB, swap=8GB, processors=14）→ `wsl --shutdown` → 重启 Docker Desktop；容器幸存（Exited 255 后 start 成功），`-j8` 恢复编译
**经验教训**: gem5 构建并行度受 VM 内存约束（12GB 用 -j8 安全）；容器 FS 内容在 daemon 崩溃重启后存活

### 决策：gem5 只能在容器内克隆/构建，Windows 端 git 有 CRLF 污染

**日期**: 2026-09-26
**问题**: Windows 全局 git autocrlf 使克隆出的 gem5 shebang 行带 `\r`（`/usr/bin/env: 'python3\r': No such file or directory`），scons Kconfig 步骤报 Error 127
**解决**: 在容器内重新克隆（Linux FS 无 CRLF 问题）；不改用户全局 git 配置
**预防**: 以后所有在 Linux/容器内执行的脚本源码，一律在容器内创建或克隆，不在 Windows 侧写后再拷贝（若必须拷贝，用 `dos2unix` 处理）

### 决策：Linux 实验环境走 Docker 而非 WSL2 原生发行版

**日期**: 2026-09-25
**背景**: gem5 无法在 Windows 原生构建；WSL 只有 docker-desktop 发行版
**理由**: Docker Desktop 已装且有 neo4j 容器使用先例；用 `ubuntu` 容器即可获得 Linux 环境，无需新装 WSL 发行版
**影响**: 所有 gem5/工具链命令在容器内执行；宿主机通过 volume 挂载 `D:\project\autoccfa`

### 决策：方法设计不依赖 LLM API

**日期**: 2026-09-25
**背景**: 用户确认无 LLM API
**影响**: 候选 idea 筛选时排除依赖 LLM 调用的方案；本地可用算力 = CPU + GTX 1650 4GB (torch 2.5.1)

## 相关文件路径

| 文件 | 路径 |
|------|------|
| 项目方法论(Sibyl) | `D:\Obsidian\notes\笔记\beansugar\vibe coding\vibe方法论\基于Sibyl Research System实践方法论.md` |
| 项目管理方法论 | `D:\Obsidian\notes\笔记\beansugar\vibe coding\vibe方法论\科研项目管理方法论.md` |
| MD转LaTeX方法论 | `D:\Obsidian\notes\笔记\beansugar\vibe coding\vibe方法论\2025-04-29-md-to-latex-converter.md` |
| 用户背景memory | `D:\Obsidian\notes\笔记\beansugar\vibe coding\memory\2026-07-29 VerilogLAVD学习状态与进组技术栈.md` |
| VerilogLAVD 项目 | `D:\project\VerilogLAVD` |
