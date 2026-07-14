---
title: "Structure-Aware Local Differential Privacy for Multimodal Collaborative Inference in Federated Learning Systems"
method_name: "Struct-DP"
authors: [Yuan Gao, Yingjie Xia, Xuejiao Liu, Oubo Ma, Shuaifan Jin, Jia-Nan Liu]
year: 2026
venue: "IEEE Transactions on Dependable and Secure Computing"
tags: [local-differential-privacy, multimodal-learning, collaborative-inference, federated-learning, representation-decoupling]
doi: "10.1109/TDSC.2026.3698059"
created: 2026-07-14
---

# 论文笔记：Structure-Aware Local Differential Privacy for Multimodal Collaborative Inference in Federated Learning Systems

## 元信息

| 项目 | 内容 |
|------|------|
| 方法名 | Struct-DP |
| 主题 | 多模态协同推理中的本地差分隐私 |
| 场景 | 联邦学习系统中的云边协同推理 |
| 主要威胁 | 特征反演攻击、影子模型攻击 |
| 数据集 | CMU-MOSI, CMU-MOSEI |
| 论文状态 | IEEE TDSC accepted author version |
| DOI | 10.1109/TDSC.2026.3698059 |

---

## 一句话总结

Struct-DP 用“共享/私有表示解耦 + 按隐私敏感度和任务重要性分配噪声”的方式，让多模态协同推理在满足 LDP 的同时少损失任务性能。

---

## 核心贡献

1. **把问题定位到多模态中间特征的异质性**：论文指出，统一加噪会同时犯两个错：任务关键维度被过度扰动，隐私敏感但任务弱相关的维度又保护不足。
2. **提出 Struct-DP 两阶段框架**：先在边缘端把多模态表示拆成可上传的 shared representation 和本地保留的 private representation，再对 shared space 做结构感知加噪。
3. **用梯度信号构建双评分噪声表**：隐私敏感度越高噪声越大，任务重要性越高噪声越小；在线阶段只需查表和加高斯噪声。
4. **理论与实验闭环**：证明机制满足 `(epsilon, delta)-LDP`，并在 CMU-MOSI/CMU-MOSEI 上展示比 uniform-noise baselines 更好的 privacy-utility trade-off。

---

## 问题背景

### 要解决的问题

云边协同推理把轻量前端放在边缘端，把重推理放在云端。边缘端不上传原始多模态数据，而是上传中间特征 `s`。问题是：这些中间特征仍然包含丰富语义和敏感属性，半诚实云服务器可以训练反演网络或影子模型，从 `s` 重构用户原始输入或推断隐私属性。

### 现有方法的局限

传统 LDP 做法通常对上传表示的所有维度注入同尺度噪声。这种 uniform perturbation 在多模态场景里很粗：

- 人脸身份、说话人音色等隐私敏感特征可能不是情感识别所必需，却仍可能残留在上传特征里。
- 表情、语调等任务关键特征需要保留，却可能被无差别噪声破坏。
- 不同模态和不同维度的隐私风险、任务贡献都不一样，粗粒度模态级预算也不够细。

### 本文动机

作者认为应先减少上传空间中的隐私暴露，再在上传空间内部做细粒度噪声分配。换句话说：先“哪些东西根本别上传”，再“必须上传的东西里，哪些维度多加噪、哪些维度少加噪”。

---

## 方法详解

### 总体架构

Struct-DP 是两阶段边缘端机制：

1. **Stage I: Shared-Private Representation Decoupling**
   - 输入多模态原始数据 `{U_m}`。
   - 每个模态先通过轻量 encoder 得到 base feature `h_m`。
   - shared branch 生成 `s_m`，作为云端可用的任务相关表示。
   - private branch 生成 `p_m`，保留在本地，吸收模态特有和隐私相关因素。

2. **Stage II: Structure-Aware Noise Injection**
   - 离线阶段用 privacy head 和 task head 估计每个维度的隐私敏感度与任务重要性。
   - 把双评分融合成噪声系数，生成 `sigma(m,d)` lookup table。
   - 在线阶段边缘端按表对 shared representation 注入异质高斯噪声，只上传 `tilde{s}_m`。

### 关键直觉

Struct-DP 的噪声策略可以概括为：

- **高隐私、低任务贡献**：多加噪。
- **低隐私、高任务贡献**：少加噪，但不低于 LDP 要求的最小高斯噪声。
- **私有表示**：不上传，直接缩小攻击面。

---

## 关键公式

### 公式1：特征反演攻击

攻击者训练重构网络 `R_phi`，从上传特征 `tilde{s}` 反推原始输入 `U`：

$$
\min_{\phi} \sum_{(U_{aux}, \tilde{s}_{aux})}
\ell_{rec}\left(R_{\phi}(\tilde{s}_{aux}), U_{aux}\right)
$$

**含义**：半诚实服务器可利用辅助数据学习从中间特征到原始输入的逆映射。

### 公式2：边缘端模态编码

$$
h_m = Enc_m(U_m; \theta_m), \quad m \in M
$$

**含义**：每个模态在边缘端先被轻量 encoder 映射到 base representation。

### 公式3：共享/私有表示拆分

$$
s_m = \Phi_s^m(h_m), \quad p_m = \Phi_p^m(h_m)
$$

**含义**：`s_m` 是候选上传空间，`p_m` 是本地保留的隐私/模态特有空间。

### 公式4：跨模态共享表示对齐

$$
\mathcal{L}_{align}
= \sum_{i=1}^{N}\sum_{(m,n)\in P}
\left\|s_m^{(i)} - s_n^{(i)}\right\|_2^2
$$

**含义**：同一样本的不同模态 shared features 应靠近，以保留跨模态共享语义。

### 公式5：特征重构损失

$$
\hat{h}_m^{(i)} = Dec_m(s_m^{(i)}, p_m^{(i)})
$$

$$
\mathcal{L}_{rec}
= \sum_{m\in M}\sum_{i=1}^{N}
\left\|\hat{h}_m^{(i)} - h_m^{(i)}\right\|_2^2
$$

**含义**：防止解耦时丢掉信息，并迫使 private branch 承接模态特有细节。

### 公式6：任务预测与任务损失

$$
\hat{y}^{(i)} = Head\left(\{s_m^{(i)}\}_{m\in M}\right)
$$

$$
\mathcal{L}_{task}
= \frac{1}{N}\sum_{i=1}^{N} CE(\hat{y}^{(i)}, y^{(i)})
$$

**含义**：只有 shared representation 被用于主任务，推动 shared space 保留判别信息。

### 公式7：正交约束

$$
\mathcal{L}_{orth}
= \sum_{m\in M}\sum_{i=1}^{N}
\left\|\left(s_m^{(i)}\right)^\top p_m^{(i)}\right\|_2^2
$$

**含义**：减少 shared/private 表示重叠，让二者承载不同因素。

### 公式8：隐私属性探测

$$
\hat{z}^{(i)} = D_{priv}(s^{(i)})
$$

$$
\mathcal{L}_{priv}
= \frac{1}{N}\sum_{i=1}^{N} CE(\hat{z}^{(i)}, z^{(i)})
$$

**含义**：离线隐私头用于定位 shared representation 中哪些维度更能预测隐私属性。

### 公式9：梯度显著性评分

$$
g_{m,d}^{(i,\kappa)}
= \left|
\frac{\partial \mathcal{L}_{\kappa}^{(i)}}{\partial s_{m,d}^{(i)}}
\right|,
\quad \kappa \in \{priv, util\}
$$

$$
G_{m,d}^{\kappa}
= \frac{1}{N}\sum_{i=1}^{N} g_{m,d}^{(i,\kappa)}
$$

**含义**：用 loss 对 shared dimension 的梯度大小衡量维度对隐私或任务的敏感度。

### 公式10：双评分融合

$$
\omega_{m,d}
= \mu s_{m,d}^{priv} - \nu s_{m,d}^{util} + b
$$

**含义**：隐私敏感度推高噪声权重，任务重要性压低噪声权重。

### 公式11：高斯机制基准噪声

$$
\sigma_{base}
= \frac{\Delta_2 \sqrt{2\ln(1.25/\delta)}}{\epsilon}
$$

**含义**：作为满足 `(epsilon, delta)-LDP` 的最小噪声尺度。

### 公式12：结构化噪声映射与释放

$$
\sigma_{m,d}
= \sigma_{min}
+ \lambda_{m,d}(\sigma_{max} - \sigma_{min})
$$

$$
\tilde{s}_{m,d}^{(i)}
= s_{m,d}^{(i)} + \mathcal{N}(0, \sigma_{m,d}^{2})
$$

**含义**：每个模态-维度位置有自己的噪声尺度；`sigma_min = sigma_base`，因此不会低于 DP 校准要求。

---

## 理论分析

### LDP 保证

作者把边缘端 pipeline 写作：

$$
T_{edge} = T_{noise} \circ T_{decoup} \circ T_{enc}
$$

释放特征为：

$$
\tilde{s} = T(U) = s(U) + \eta,\quad \eta \sim \mathcal{N}(0,\Sigma)
$$

由于所有维度的噪声尺度都满足高斯机制的下界，且编码与解耦是输入的确定性函数，整条边缘端机制继承 `(epsilon, delta)-LDP` 保证。

### 结构化噪声优于均匀噪声的条件

论文用 weighted MSE 衡量任务损失：

$$
WMSE(\sigma^2)
= \sum_{d=1}^{D} w_d\sigma_d^2
$$

如果噪声方差与任务权重反向排列，即任务越重要的维度噪声越小，那么在相同总方差预算下，结构化分配的加权失真低于均匀分配。

### 对重构攻击的防御

高斯噪声给重构引入不可消除误差。对 privacy-critical subspace，Struct-DP 分配更大的方差，使攻击者即使用强重构器也难以恢复真实特征结构。

---

## 关键图表

### Figure 1: System architecture / 攻击场景

说明云边协同推理中，边缘端上传中间特征 `s`，半诚实云服务器通过反演网络 `R_phi` 恢复敏感内容。图中强调不同模态/维度具有不同隐私风险。

### Figure 2: Struct-DP overview / 方法总览

展示两阶段流程：先生成 `s_m` 和本地 `p_m`，再用 task/privacy gradients 构造 `sigma(m,d)` 噪声表，最后只上传加噪 shared features。

### Figure 3: CMU-MOSEI training dynamics

展示 Struct-DP 在 CMU-MOSEI 上训练收敛，Acc-2 与 MAE 曲线接近无隐私扰动的 MISA baseline，说明结构化扰动没有显著破坏学习能力。

### Figure 4: CMU-MOSEI utility across epsilon and C

比较不同 privacy budget 和 clipping norm 下的 Acc-2/Acc-7。结论是 Struct-DP 在强隐私预算下优势更明显。

### Figure 5: CMU-MOSI utility across epsilon and C

在较小的 CMU-MOSI 数据集上重复验证，说明优势不只来自大数据集规模。

### Figure 6: Privacy-utility Pareto boundary

Struct-DP 在 CMU-MOSEI 和 CMU-MOSI 上更靠近高准确率、高 MSE 的理想区域。文中举例：在高安全水平下，uniform baselines 的 accuracy 可降到 70% 以下，而 Struct-DP 仍保持约 77% Acc-2。

### Figure 7: Reconstruction MSE across privacy budgets

在 CMU-MOSEI 上，`epsilon = 0.5` 时 Struct-DP 的重构 MSE 为 2.79，高于 Global-Uniform-DP 1.52、Shared-Uniform-DP 0.40、Modality-Adaptive-DP 1.12。

### Figure 8: Qualitative reconstruction comparison

无 DP 的重构最接近真实特征；uniform 和 modality-adaptive 方法仍保留明显包络与趋势；Struct-DP 使重构信号出现大幅偏移和高频混乱，更难用于恶意分析。

### Figure 9: Ablation of privacy/importance modules

在 CMU-MOSEI，`C = 0.1, epsilon = 0.5`：

| Variant | Utility | Privacy |
|---------|---------|---------|
| Importance-Only | Acc-2 = 0.838，最高 | MSE = 0.35，隐私弱 |
| Privacy-Only | Acc-2 = 0.735，性能下降 | MSE = 2.85，隐私强 |
| Struct-DP | Acc-2 = 0.823 | MSE = 2.79 |

结论：只看任务或只看隐私都会失衡，双评分融合才是关键。

### Tables

抽取文本中未检测到显式 Table caption；论文主要用 Figure 3-9 呈现实验结果。

---

## 实验

### 数据集

| 数据集 | 任务 | 特点 |
|--------|------|------|
| CMU-MOSEI | 多模态情感分析 | 大规模 benchmark，使用官方 train/validation/test split |
| CMU-MOSI | 多模态情感分析 | 较小规模 benchmark，用于鲁棒性验证 |

### Baselines

| 方法 | 说明 |
|------|------|
| No-DP | 无隐私扰动的 MISA backbone |
| Global-Uniform-DP | 在融合多模态表示上统一加高斯噪声 |
| Shared-Uniform-DP | 先共享/私有解耦，但在 shared space 中统一加噪 |
| Modality-Adaptive-DP | 模态级自适应噪声分配 |
| Struct-DP | 维度级 privacy/utility 双评分结构化加噪 |

### 实现细节

- Backbone: MISA。
- 训练：Adam，200 epochs，learning rate `1e-4`。
- 隐私预算：`epsilon in {0.5, 1.0, 2.0, 4.0, 8.0}`。
- Clipping norm：`C in {0.1, 0.2, 0.3, 0.5, 1.0}`。
- CMU-MOSEI：batch size 64，dropout 0.5。
- CMU-MOSI：batch size 16，dropout 0.1。
- 文本特征：Tiny-BERT-based model。
- 视觉特征：ResNet-based CNN。

### 指标

- Utility: Acc-2, Acc-7, MAE。
- Privacy: reconstruction MSE，越高表示重构越差、隐私防御越强。

### 主要结果

1. Struct-DP 保留约 98.2% 的 peak task utility。
2. 在严格隐私预算 `epsilon = 0.5` 下，重构 MSE 相比 uniform-noise baseline 约提升 7x。
3. 在 CMU-MOSEI 上，`epsilon = 0.5` 时：
   - Struct-DP: MSE 2.79。
   - Global-Uniform-DP: MSE 1.52。
   - Shared-Uniform-DP: MSE 0.40。
   - Modality-Adaptive-DP: MSE 1.12。
4. Struct-DP 对 clipping norm 增大更稳健，因为它把噪声从 task-critical dimensions 转移到 less task-critical / more privacy-sensitive subspaces。

---

## 批判性思考

### 优点

1. **问题建模合理**：多模态表示确实具有维度/模态异质性，统一加噪很容易浪费隐私预算。
2. **机制工程上可部署**：离线计算评分表，在线只查表加噪，适合边缘设备实时推理。
3. **对照实验有针对性**：No-DP、global uniform、shared uniform、modality-adaptive 都能分别隔离解耦和噪声分配的作用。
4. **理论边界清楚**：没有声称突破 DP 本身，而是在高斯机制约束下优化 utility distortion。

### 局限性

1. **静态校准依赖强**：`sigma(m,d)` 表来自训练分布，真实数据分布漂移后 privacy-utility trade-off 可能退化。
2. **在线自适应不足**：更新噪声表需要重新校准，论文也承认这是未来工作。
3. **隐私标签/探测头依赖**：privacy head 需要可定义的敏感属性标签；如果隐私因素不可观测或标签偏差大，评分会不稳定。
4. **任务范围仍偏窄**：实验集中在多模态情感分析，尚未证明对 VLM、医疗多模态、机器人多模态推理等场景同样有效。

### 潜在改进方向

1. 设计轻量 online sensitivity tracking，避免分布漂移时完全重新校准。
2. 引入无监督或对比式 privacy probes，减少对显式隐私标签的依赖。
3. 在更复杂的多模态任务中测试，例如 VQA、视频理解、医学多模态诊断。
4. 把噪声分配与通信/延迟预算联合优化，形成真正的边缘端部署策略。

### 可复现性评估

- [ ] 代码开源：PDF 中未检测到代码链接。
- [ ] 预训练模型：未检测到明确提供。
- [x] 训练细节：给出了 optimizer、epoch、learning rate、batch/dropout、epsilon/C 设置。
- [x] 数据集可获取：CMU-MOSI 和 CMU-MOSEI 是常用公开 benchmark。
- [ ] 图中完整数值：多数结果以曲线/柱状图呈现，文本只给出部分关键数值。

---

## 关联概念

- [[Local Differential Privacy]]：本地端随机化机制，上传前即提供隐私保证。
- [[Gaussian Mechanism]]：本文的基本 DP 加噪机制。
- [[Multimodal Collaborative Inference]]：边缘上传中间特征、云端完成推理的部署范式。
- [[Feature Inversion Attack]]：从中间表示恢复原始输入。
- [[Representation Decoupling]]：将 shared/task-relevant 与 private/sensitive 表示分离。
- [[MISA]]：本文实验 backbone。
- [[CMU-MOSI]] / [[CMU-MOSEI]]：多模态情感分析 benchmark。

---

## 速查卡片

> [!summary] Struct-DP
> - **核心**：维度级结构化 LDP 噪声分配。
> - **方法**：shared/private 解耦 + privacy/utility gradient scoring + Gaussian lookup table。
> - **结果**：保留约 98.2% peak utility，严格隐私预算下重构 MSE 约比 uniform baseline 高 7x。
> - **关键风险**：静态噪声表遇到分布漂移会退化，隐私评分依赖 privacy labels/probes。

---

## 自检

- [x] 已覆盖 Figure 1-9 的题注和作用。
- [x] 未检测到显式 Table。
- [x] 已列出主要公式与含义。
- [x] 已包含实验设置、指标、baselines 和关键数值。
- [x] 已给出批判性分析与复现性评估。
