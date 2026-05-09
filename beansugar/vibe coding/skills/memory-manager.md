---
name: memory-manager
description: 管理项目的 MEMORY.md 文件。在项目启动时自动创建，在开发过程中持续更新，记录用户偏好、项目配置、进度、问题、决策和经验教训。
when_to_use: |
  当出现以下任一情况时自动触发：
  1. 用户要求新建项目或初始化项目
  2. 用户要求"更新 memory"、"记录进度"、"更新状态"
  3. 完成一项任务或修复一个问题后
  4. 用户做出关键技术选型决策
  5. 项目路径/环境配置发生变化
  6. 用户要求"查看项目状态"、"当前进度如何"
argument-hint: "[项目路径] 或 [更新内容]"
disable-model-invocation: false
user-invocable: true
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob]
effort: medium
---

# 🧠 项目记忆管理器

你的职责是管理项目的 `MEMORY.md` 文件，确保项目上下文被完整、规范地记录，使得任何 AI 协作者（Claude Code / OpenCode / Cursor 等）都能通过读取此文件快速理解项目全貌。

---

## 一、核心原则（必须遵守）

### 1. 绝对路径原则 ⭐
**所有文件路径必须使用从盘符开始的完整绝对路径。**

```
✅ D:\Projects\my-app\src\main.py
❌ src/main.py
❌ ../main.py
```

### 2. 即时记录原则
**问题解决/重要修改/实验完成后立即更新 MEMORY.md，不等第二天。**

### 3. 详略得当原则
- ✅ 关键步骤、踩坑经历、创新点 → 详细记录
- ⚠️ 常规操作、已知内容 → 简要记录或省略

### 4. 可追溯原则
每个修改必须有文件路径，每个问题必须有解决方案，每个决策必须有理由。

---

## 二、文件顶层结构

MEMORY.md 使用以下固定结构。**首次创建时写入完整框架，后续仅更新对应区块。**

```markdown
# 用户偏好

# 当前项目：[项目名称]

## 项目配置

## 当前进度

## 当前状态

## 决策记录

## 历史记录

### [YYYY-MM-DD] 主题

## 项目子模块

### 子模块名称

## 会议/讨论记录
```

---

## 三、各区块规范详解

### 3.1 用户偏好（必填）

**作用**：记录用户个性化配置，避免重复询问。

```markdown
# 用户偏好

- **语言**: 始终使用中文回答
- **操作系统**: Windows / macOS / Linux
- **包安装规则**: （如有）所有 Python 包必须安装到 `D:\pythonpackage\packages`
- **代码风格**: 使用类型注解、添加 docstring、遵循 PEP8
- **其他偏好**: （逐条列出）
```

**规则**：
- 用户没有明说的偏好不要编造
- 用户说过一次后立即记录
- 对话中用户纠正了你 → 立即更新偏好

### 3.2 当前项目

```markdown
# 当前项目：[项目名称]
```

项目名称应简洁明了，如 `植物病害识别系统`、`论文写作`。

### 3.3 项目配置

```markdown
## 项目配置

- **路径**: `D:\Projects\my-app`
- **环境**: thesis conda 环境 (CUDA 12.1, GTX 1650 4GB)
- **Python路径**: `C:/Users/24796/.conda/envs/thesis/python.exe` ⚠️ 必须使用 conda 环境，不能用系统 Python
- **PYTHONPATH**: `D:\pythonpackage\packages`

### 命令模板
- **安装依赖**: `pip install -r requirements.txt`
- **启动训练**: `python train.py --config configs/default.yaml`
- **运行测试**: `pytest tests/ -v`
```

**规则**：
- 路径必须是绝对路径
- 标注注意事项（如 ⚠️ 标记）
- 记录常用的长命令，避免重复输入

### 3.4 当前进度

使用状态符号跟踪任务：

| 符号 | 含义 |
|------|------|
| `✅` | 已完成 |
| `⏳` | 进行中 |
| `⚠️` | 有问题/阻塞 |
| `❌` | 失败/废弃 |

```markdown
## 当前进度

1. ✅ 数据预处理完成（5000 张图像，20 个类别）
2. ⏳ 模型训练中（Swin Transformer, 当前 epoch 15/50）
3. ⚠️ 验证集 AUC 偏低（0.62），需要排查
4. ⏳ 论文第二章写作（预计 3 天完成）
```

**规则**：
- 每条进度必须包含关键数字或具体描述
- ❌ 坏例子：`✅ 训练完成` → ✅ 好例子：`✅ 训练完成（50 epochs, 显存占用 11%, 准确率 92.3%）`
- 保持 3-8 条当前进行中的事项，过时的移入历史记录

### 3.5 当前状态

```markdown
## 当前状态

- 项目阶段：模型训练 + 论文写作并行
- 阻塞问题：验证集 AUC 异常低，检查数据标签是否正确
- 下一步计划：完成训练 → 生成可视化 → 补充论文实验章节
- 上次更新：2025-03-20
```

**规则**：简洁快照，不超过 5 行。详细过程记录在历史记录中。

### 3.6 决策记录

```markdown
## 决策记录

### 决策：[决策简述]

**日期**：YYYY-MM-DD

**背景**：[决策前的约束条件]

**方案对比**：

| 方案 | 优点 | 缺点 | 最终选择 |
|------|------|------|----------|
| 方案A | ... | ... | |
| 方案B | ... | ... | ⭐ |

**理由**：
1. [核心原因]

**影响**：[后续影响]
```

**触发时机**：技术选型（框架/模型/工具）、实验方案调整、架构设计决定。

### 3.7 历史记录

```markdown
## 历史记录

### [YYYY-MM-DD] 修复 ROC 曲线模型加载错误

#### 1. 修复 ROC 曲线模型加载错误 ✅

**问题**:
1. ROC 曲线 AUC 只有 0.47（接近随机预测 0.5）
2. 模型预测接近随机状态
3. 使用 `strict=False` 加载导致参数未正确匹配

**根本原因**:
- checkpoint 键名与模型键名不匹配

**解决方案**:
1. 使用 `strict=True` 确保完全匹配
2. 编写键名检查工具验证匹配情况

**修改文件**:
- `D:\Projects\thesis\Code\tools\generate_roc_curves.ipynb` - 修正 3 处加载代码
- `D:\Projects\thesis\Code\tools\check_checkpoint_keys.py` - 新建诊断工具

**验证方法**:
- 运行 ROC 生成脚本，确认 AUC > 0.85

**经验教训**:
- 模型加载
  - 问题：checkpoint 键名与模型键名不匹配
  - 解决：使用 `strict=True` 确保完全匹配
  - 预防：加载前先检查键名格式，使用诊断工具
```

**问题标题命名规则**：`动词 + 对象 + 目的/结果`

```
✅ 修复 ROC 曲线模型加载错误
✅ 优化数据集样本展示图字体
✅ 补充第二章损失函数理由
❌ ROC 曲线问题
❌ 字体优化
❌ 补充内容
```

**每条历史记录必须包含**：
- 问题现象 → 根本原因 → 解决方案 → 修改文件（绝对路径）→ 验证方法 → 经验教训

### 3.8 项目子模块

```markdown
## 项目子模块

### 数据处理
- 路径: `D:\Projects\thesis\Code\data_preprocessing`
- 职责: 图像预处理、数据集划分、数据增强
- 关键文件:
  - `D:\Projects\thesis\Code\data_preprocessing\split_dataset.py` - 数据集划分
  - `D:\Projects\thesis\Code\data_preprocessing\augmentation.py` - 数据增强

### 模型训练
- 路径: `D:\Projects\thesis\Code\training`
- 职责: 模型定义、训练循环、checkpoint 管理

### 可视化
- 路径: `D:\Projects\thesis\Code\tools`
- 职责: ROC 曲线、混淆矩阵、样本展示图生成

### 论文
- 路径: `D:\Projects\thesis\03_Overleaf上传模板\data`
- 职责: LaTeX 各章节源文件
```

### 3.9 会议/讨论记录

```markdown
## 会议/讨论记录

### [YYYY-MM-DD] 与导师讨论：实验方案调整

**参会人**: 导师

**讨论要点**:
1. 当前 Swin Transformer 效果未达预期
2. 建议补充 ResNet-50 作为 baseline 对比
3. 第二章需要补充损失函数选择的理由

**待办事项**:

| 任务 | 负责人 | 截止日期 | 状态 |
|------|--------|----------|------|
| 训练 ResNet-50 baseline | 我 | 2025-03-25 | ⏳ |
| 补充损失函数理由 | 我 | 2025-03-23 | ✅ |
| 审阅第二章 | 导师 | 2025-03-28 | ⏳ |
```

---

## 四、工作流

### 首次创建 MEMORY.md

```markdown
1. 询问用户确认项目根目录路径（绝对路径）
2. 询问用户偏好的语言、代码风格等
3. 探测项目环境（Python 版本、conda 环境、CUDA 等）
4. 创建 MEMORY.md 骨架（包含所有二级标题）
5. 填写"用户偏好"和"项目配置"
6. 告知用户："MEMORY.md 已创建，有进展时我会自动更新"
```

### 日常更新 MEMORY.md

```markdown
1. 完成任务后 → 更新"当前进度"区块
2. 遇到问题并解决后 → 在"历史记录"中新增一条，更新进度
3. 做出决策后 → 在"决策记录"中新增一条
4. 用户纠正某个偏好 → 更新"用户偏好"
5. 当前状态有重大变化 → 更新"当前状态"的时间戳和内容
```

### 更新粒度

```markdown
- 不要每次微小的文件修改都更新 MEMORY.md
- 在以下时机更新：
  ✅ 一个独立任务完成时
  ✅ 一个 bug 被修复时
  ✅ 一次实验得出结果时
  ✅ 用户做出关键决策时
  ✅ 对话结束时（如果本轮有进展）
  ❌ 每次修改一行代码
  ❌ 每次运行测试命令
```

---

## 五、实验结果记录模板

当用户完成一次实验，在"历史记录"中插入：

```markdown
### [YYYY-MM-DD] 实验：[实验名称]
例子：
**实验配置**:
- 模型：Swin Transformer (swin_tiny_patch4_window7_224)
- 数据集：植物病害 20 分类，训练集 4000 张，验证集 1000 张
- 超参数：batch_size=32, lr=0.001, epochs=50, optimizer=AdamW

**实验结果**:
- 准确率：92.3%
- 精确率：91.8%
- 召回率：92.1%
- F1-Score：91.9%
- 训练时间：4 小时 23 分（GTX 1650）

**对比**:

| 方法 | 准确率 | 参数量 | 训练时间 |
|------|--------|--------|----------|
| ResNet-50 | 88.5% | 25.6M | 3h 12min |
| **Swin-T** | **92.3%** ⭐ | 28.3M | 4h 23min |

**结论**:
- Swin-T 比 ResNet-50 准确率提升 3.8%，训练时间增加 37%
- 当前 batch_size=32 时显存占用 11%，还有余量可尝试更大 batch
```

---

## 六、经验教训记录格式

```markdown
**经验教训**:
1. **[类别名称]**
   - 问题：[具体描述了什么问题]
   - 解决：[用了什么方法]
   - 预防：[下次如何避免]
```

**常见类别**：模型加载、数据处理、环境配置、性能优化、调试技巧、文件管理。

---

## 七、代码修改记录格式

```markdown
#### 文件：`D:\Projects\thesis\Code\tools\generate_roc_curves.ipynb`

**修改前**:
```python
model.load_state_dict(torch.load(ckpt_path), strict=False)
```

**修改后**:
```python
checkpoint = torch.load(ckpt_path)
checkpoint_keys = set(checkpoint.keys())
model_keys = set(model.state_dict().keys())
unexpected = checkpoint_keys - model_keys
if unexpected:
    raise KeyError(f"Unexpected keys in checkpoint: {unexpected}")
model.load_state_dict(checkpoint, strict=True)
```

**原因**: strict=False 会跳过键名不匹配，导致部分参数未加载，模型预测随机
```

---

## 八、快速检查清单

更新 MEMORY.md 后，自检以下项目：

- [ ] 所有文件路径是否为绝对路径（从盘符开始）
- [ ] 问题描述是否包含现象 + 影响 + 原因
- [ ] 解决方案是否步骤清晰、可复现
- [ ] 修改的文件是否都有记录
- [ ] 进度项是否包含关键数字/具体描述
- [ ] 状态符号是否正确（✅ ⏳ ⚠️ ❌）
- [ ] 日期格式是否为 YYYY-MM-DD
- [ ] 经验教训是否归类总结

---

## 九、注意事项

1. **不要过度记录**：每次小改动都更新 MEMORY.md 会造成噪音。在独立任务完成、bug 修复、实验出结果、对话结束时更新。
2. **路径 Windows 风格**：使用反斜杠 `D:\path\to\file`，代码块内统一用反引号包裹 `` `D:\path\to\file` ``。
3. **不需要 README 开头**：MEMORY.md 不要写"# MEMORY"作为标题，直接以"# 用户偏好"开头。
4. **分离关注点**：MEMORY.md 是项目记忆，不是项目文档。README.md 负责对外介绍，MEMORY.md 负责对内记录。
5. **版本控制**：MEMORY.md 应纳入 git 版本控制，随代码一起提交。
6. **保密**：不要在 MEMORY.md 中记录 API 密钥、密码、Token 等敏感信息。

---

## 十、最小可用示例

以下是一个项目刚启动时的 MEMORY.md 最小骨架：

```markdown
# 用户偏好

- **语言**: 始终使用中文回答

# 当前项目：[项目名称]

## 项目配置

- **路径**: `D:\Projects\my-project`
- **环境**: base conda 环境
- **Python路径**: `C:/Users/24796/.conda/envs/base/python.exe`

## 当前进度

1. ⏳ 项目初始化完成，待开始开发

## 当前状态

- 项目阶段：初始化
- 下一步计划：明确需求后开始开发
- 上次更新：YYYY-MM-DD

## 决策记录

（暂无）

## 历史记录

（暂无）

## 项目子模块

（待开发后补充）

## 会议/讨论记录

（暂无）
```
