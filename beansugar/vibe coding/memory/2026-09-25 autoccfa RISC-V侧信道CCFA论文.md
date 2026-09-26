# 2026-09-25 autoccfa RISC-V侧信道CCFA论文

> **状态: 全流程已完成（2026-09-26）** — 从选题到 LaTeX 论文成品的完整自动科研闭环

# 用户偏好

- **语言**: 始终使用中文回答
- **包安装规则**: Python包装到 `D:\pythonpackage\py312-packages`（pip --target），或用 conda 环境
- **代码风格**: 脚本可复现，路径全部用绝对路径
- **数据铁律**: 论文中所有数字必须来自真实运行，禁止编造

# 项目档案（最终状态）

## 项目配置

| 项 | 值 |
|----|----|
| 项目根目录 | `D:\project\autoccfa`（含 README.md 总览） |
| 主环境 | `D:/Anaconda2024/python.exe` + `PYTHONPATH=D:/pythonpackage/py312-packages` |
| 深度学习环境 | `C:/Users/24796/.conda/envs/thesis/python.exe`（torch 2.5.1+cu121, GTX 1650） |
| gem5 容器 | **已删除（2026-09-26 用户批准方案3）**——原 `gem5build` 容器（gem5 v24.1.0.0 源码编译 `scons -j8` + riscv64-unknown-elf-gcc 13.2.0）已随镜像/发行版/vhdx 全部清除，D 盘回收 21.7GB。**重建: 运行 `D:\project\autoccfa\scripts\rebuild_env.sh`（一键脚本，含全部踩坑修复），约 1-1.5h** |
| 容器内路径 | gem5: `/gem5src`；项目挂载: `/autoccfa`；本地盘输出: `/e3fast` |
| LaTeX | `D:\project\autoccfa\tools\tectonic.exe`（0.15.0） |
| WSL 配置 | `C:\Users\24796\.wslconfig`（memory=12GB, swap=8GB）— gem5 编译 OOM 事故后新建 |
| 选题 | RVV 向量缓存时序信道刻画 + HPM/ML 可检性 + gem5 RVV 保真度审计 |
| 投稿目标 | DAC 2027（截稿 2026-11-17 AoE），备选 DATE/ACSAC/HOST |

## 成品

- **论文**: `D:\project\autoccfa\paper\autoccfa_paper\main.pdf`（7页 IEEE 双栏；tectonic 编译通过；28条引用全解析；页面逐页目检通过）
- **Overleaf 上传指南**: `D:\project\autoccfa\paper\autoccfa_paper\UPLOAD_GUIDE.md`
- **MD 主稿**: `D:\project\autoccfa\paper\autoccfa_paper.md`
- **项目总览**: `D:\project\autoccfa\README.md`

## 最终结果数字（全部真实测量，产物在 experiments/）

### 信道刻画（E1, 12 runs）
- 全部 6 变体（scalar + vle e16/m1, e32/m1, e64/m1, m2, m4）× 2 seeds: **guess_rate = 1.0**（320/320, Wilson 95% CI [0.988,1.0]）
- hit=21 / miss=106 cycles, gap=85, Cohen's d −2.60~−2.75, MI=1.0

### 鲁棒性（E2 15 runs + A2 离线量化）
- 计时器量化: ≤85cyc 猜测率恒 1.0；≥128cyc → 随机（1.6%）——临界点=hit/miss gap
- L2 128K/512K + assoc4: 稳健（gap 85）；L2=1M: gap 85→16（驱逐失效但 L1/L2 残差仍在，argmin 仍 100%）
- RandomRP: guess 0.9938–0.9969，热行 1→9.2–9.4 均值/17–19 最大

### 检测（E3 24 runs, HPM 每 1e5 cycles 快照, 84 特征）
- 二分类（attack vs benign, 9v15）5折CV: LogReg/RF/CNN 全部 acc=F1=AUC=TPR@FPR1%=1.0
- 多类归因（8类×3seeds）: macro-F1=0.354（如实报告）
- 主特征: writebacks 方差、icache 压力（向量代码 icache 取指 4.4×: 5.41M vs 1.22M）、分支误预测率

### 保真度审计（gem5 v24.1 RVV, 论文发现）
- F1: **vluxei64 gather 功能损坏**（lane0 数据=0 应为1004；不装线 probe=134cyc；gather攻击=随机4/320）复现 `code/workloads/gather_debug3.c`
- F2: **向量足迹不随 LMUL 缩放**（e64/m4 架构128B 应跨2行，实测恒1行）
- F3: 向量代码 icache 取指 4.4× 异常
- F4/F5（正面）: vle 数据/装线正确；rdcycle=精确周期

## 实验清单（51 runs 全部有 manifest+sha256）

| 实验 | 规模 | 产物 |
|------|------|------|
| E1 泄露刻画 | 12 runs | `experiments/e1_leakage/`（summary/timer_quant CSV） |
| E2 几何敏感性 | 15 runs | `experiments/e2_geometry/` |
| E3 检测 | 24 runs | `experiments/e3_detection/`（analysis.hpm.csv 10581快照） |
| 冒烟+调试 | 若干 | `experiments/smoke_*/`, `logs/` |

## 关键技术事实（复用价值）

1. **O3 计时模板**: `csrr t0; ld; addi(dep); fence rw,rw; csrr t1` —— 无 fence 时第二次 csrr 被乱序提前执行，miss 不可见
2. gem5 ticks≠cycles：1GHz → 1000 ticks/cycle（periodicStatDump 参数按 ticks）
3. `-nostdlib` 必须 `-fno-builtin`（gcc 会把手写循环替换成 libc 调用）
4. RVV: VLEN=256/ELEN=64 → e64/m1 的 vl=4；vluxei 索引单位=元素(8B)；无 libc 时 shebang/输出函数都易踩坑
5. Windows git autocrlf 污染 Linux 脚本 → 容器内克隆
6. 9p 挂载写大量小文件极慢 → gem5 stats 输出走容器本地盘，结束后 docker cp

## 遗留事项（给用户）

- [x] 2026-09-26 环境清理: 用户批准方案3，已删 gem5build 容器+全部镜像+docker-desktop 发行版+docker_data.vhdx（21.7GB），D 盘 38GB→59GB；Docker Desktop 已重启为全新空环境；一键重建脚本 `D:\project\autoccfa\scripts\rebuild_env.sh`
- [ ] 论文人工审阅 + 导师意见（尤其贡献定位与相关工作的边界表述）
- [ ] DAC 2027 注册与截稿确认（2026-11-17 AoE）
- [ ] 可选增强: 投机向量访存原语（Spectre-gather）、防御评估（fence/way-pin）、更多 benign 负载、跨核竞争
- [ ] C 盘只剩 ~3GB（98%）——与本项目无关（Docker vhdx 在 `D:\DockerData`），建议按你的《C盘清理评估》处理
- [ ] gem5 gather bug 可考虑上游报 issue（复现脚本已备好）

## 项目方法论文件

| 文件 | 路径 |
|------|------|
| 项目方法论(Sibyl) | `D:\Obsidian\notes\笔记\beansugar\vibe coding\vibe方法论\基于Sibyl Research System实践方法论.md` |
| 项目管理方法论 | `D:\Obsidian\notes\笔记\beansugar\vibe coding\vibe方法论\科研项目管理方法论.md` |
| MD转LaTeX方法论 | `D:\Obsidian\notes\笔记\beansugar\vibe coding\vibe方法论\2025-04-29-md-to-latex-converter.md` |
| 用户背景 | `D:\Obsidian\notes\笔记\beansugar\vibe coding\memory\2026-07-29 VerilogLAVD学习状态与进组技术栈.md` |
| 文献报告 | `D:\project\autoccfa\lit\01_attack_landscape.md`, `lit\02_defense_detection_landscape.md` |
| 决策/大纲/审计 | `D:\project\autoccfa\docs\04_decision.md`, `docs\05_paper_outline.md`, `docs\06_audit_table.md` |
