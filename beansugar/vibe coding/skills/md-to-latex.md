---
name: md-to-latex
description: 将 Markdown 格式的学术论文转换为完整的、可编译的 LaTeX 工程（符合 ACM 标准）
---
---

name: md-to-latex

description: 将 Markdown 格式的学术论文转换为完整的、可编译的 LaTeX 工程（支持 Overleaf 和本地编译）

---

  

## 触发条件（TRIGGER WHEN）

- 用户在 `D:\md_to_latex\md\` 目录下有一个 `.md` 格式的学术论文初稿，需要转换为 LaTeX 格式

- 用户提到 "将 MD 转为 LaTeX"、"创建 LaTeX 论文工程"、"生成学术 LaTeX 项目" 等类似需求

- 用户需要生成符合学术标准的论文格式，同时支持 Overleaf 在线编辑

- 用户请求将 Markdown 论文组织为可编译的 LaTeX 目录结构

  

**工作流程**：

- **输入**：`D:\md_to_latex\md\{论文题目}.md`

- **输出**：`D:\md_to_latex\to_project\{论文题目}\` 完整 LaTeX 项目（包含 Overleaf 和本地两个版本）

  

## 输入要求

- **源文件路径**：`D:\md_to_latex\md\` 目录下的 Markdown 文件（.md）

- **文件命名**：MD 文件名即为论文题目（如 `MyPaper.md` → 论文题目为 "MyPaper"）

- **建议**：文件应包含标准的章节结构（使用 `#`、`##` 标题）

- **建议**：文件应包含摘要（Abstract）和关键词（Keywords）

- **建议**：文件末尾包含参考文献列表（References）

  

## 执行步骤

  

### 1. 环境准备与目录创建

1. 确认源目录：`D:\md_to_latex\md\`

2. 在 `D:\md_to_latex\to_project\` 下创建以论文题目命名的项目文件夹

3. 创建以下目录结构：

  

```

D:\md_to_latex\to_project\

└── {论文题目}/

    ├── main.tex              # Overleaf 版本主文件

    ├── main_local.tex        # 本地编译版本主文件

    ├── ref.bib              # 参考文献数据库

    ├── README.md            # 项目说明文档

    ├── UPLOAD_GUIDE.md      # 上传指南

    ├── data/                # 章节内容目录

    │   ├── 00_abstract.tex  # 摘要

    │   ├── 01_intro.tex     # 引言

    │   ├── 02_related_work.tex  # 相关工作

    │   ├── 03_method.tex    # 方法

    │   ├── 04_experiments.tex # 实验

    │   ├── 05_discussion.tex # 讨论

    │   └── 06_conclusion.tex # 结论

    ├── figures/             # 图片存放目录

    └── test/                # 测试文件和辅助工具

        ├── test.tex         # 本地测试文件

        ├── test_overleaf.tex # Overleaf 测试文件

        ├── compile.bat      # 编译脚本

        ├── diagnose.bat     # 诊断工具

        └── README_OVERLEAF.md  # Overleaf 详细指南

```

  

### 2. 内容解析与转换

  

#### 2.1 读取并解析 MD 文件

- 从 `D:\md_to_latex\md\` 目录读取目标 MD 文件

- 识别章节标题（`#`、`##`、`###`）

- 提取每个章节的内容

  

#### 2.2 提取摘要和关键词

- 识别并提取 MD 文件开头的 `**Abstract**` 和 `**Keywords**` 部分

- 将摘要内容写入 `data/00_abstract.tex`

- **摘要格式**：使用 `\section*{Abstract}` 或在主文件中使用 `\abstract{}` 命令

  

#### 2.3 转换章节到独立文件

- 将每个主要章节内容写入 `data/` 下对应的 `.tex` 文件

- **标题转换规则**：

  - `# 标题` → `\section{标题}`

  - `## 标题` → `\subsection{标题}`

  - `### 标题` → `\subsubsection{标题}`

  

#### 2.4 格式转换

- **表格**：MD 表格 → LaTeX `table` 环境，使用 `booktabs` 宏包

- **数学公式**：

  - 行内公式：`$公式$` → 保持不变

  - 独立公式：`$$公式$$` → `\[公式\]` 或 `equation` 环境

- **列表**：转换为 `itemize` 或 `enumerate` 环境

- **代码块**：转换为 `verbatim` 或 `listings` 环境

- **图片**：提取图片引用，在 `figures/` 创建占位符

- **特殊字符**：转义 LaTeX 特殊字符（如 `_`、`&`、`%`、`#`）

  

### 3. 参考文献处理

  

#### 3.1 提取和解析

1. 提取 MD 文件末尾的 References 列表

2. 解析每条参考文献信息（作者、标题、年份、出处等）

3. 识别参考文献类型（article、inproceedings、misc、book等）

  

#### 3.2 生成 BibTeX 文件

1. 写入 `ref.bib` 文件

2. **重要优化**：

   - 清理空字段，避免编译问题

   - 使用标准的 BibTeX 条目格式

   - 确保 author、title、year 等关键字段完整

   - arXiv 论文使用 `journal = {arXiv preprint arXiv:xxxx.xxxxx}` 格式

  

#### 3.3 引用命令处理

- 在正文中将 `[1]`、`[2]` 等引用转换为 `\cite{key}` 格式

- 确保 cite key 与 BibTeX 文件中的 entry key 匹配

  

### 4. 主文件组装

  

#### 4.1 Overleaf 版本（main.tex）

**推荐用于在线编辑和协作**

  

```latex

\documentclass[10pt]{article}

  

% 标准包配置 - Overleaf 兼容性最佳

\usepackage[utf8]{inputenc}

\usepackage[T1]{fontenc}

\usepackage{graphicx}

\usepackage{amsmath}

\usepackage{amssymb}

\usepackage{booktabs}

\usepackage[margin=1in]{geometry}

\usepackage[hidelinks]{hyperref}  % 去除链接彩色框

\usepackage[numbers]{natbib}      % 引用支持

  

\title{\textbf{论文标题}}

\author{作者信息}

\date{\today}

  

\begin{document}

  

\maketitle

  

% 摘要 - 直接包含在主文件中

\section*{Abstract}

摘要内容...

  

\textbf{Keywords}: 关键词1, 关键词2

  

% 引入各章节

\input{data/01_intro.tex}

\input{data/02_related_work.tex}

\input{data/03_method.tex}

\input{data/04_experiments.tex}

\input{data/05_discussion.tex}

\input{data/06_conclusion.tex}

  

% 参考文献 - 使用标准样式

\bibliographystyle{plainnat}  % natbib 配套样式，稳定可靠

\bibliography{ref}

  

\end{document}

```

  

#### 4.2 本地编译版本（main_local.tex）

**用于本地高级功能定制**

  

```latex

\documentclass[sigconf,anonymous]{acmart}

  

% 自定义包配置

\usepackage[utf8]{inputenc}

\usepackage{graphicx}

\usepackage{amsmath}

\usepackage{amssymb}

\usepackage{booktabs}

\usepackage{geometry}

\usepackage[hidelinks]{hyperref}

\usepackage{natbib}

  

% ACM 专用命令

\title{论文标题}

\author{作者信息}

\date{\today}

  

\abstract{摘要内容...}

\keywords{关键词1, 关键词2}

  

\begin{document}

  

\maketitle

  

% 引入各章节

\input{data/01_intro.tex}

\input{data/02_related_work.tex}

\input{data/03_method.tex}

\input{data/04_experiments.tex}

\input{data/05_discussion.tex}

\input{data/06_conclusion.tex}

  

% 参考文献

\bibliography{ref}

\bibliographystyle{ACM-Reference-Format}

  

\end{document}

```

  

### 5. 文档和辅助文件创建

  

#### 5.1 项目文档

创建 `README.md` 包含：

- 项目结构说明

- 文件用途说明

- 快速开始指南

- 编译说明

  

#### 5.2 上传指南

创建 `UPLOAD_GUIDE.md` 包含：

- Overleaf 上传步骤

- 文件选择说明

- 常见问题解决

  

#### 5.3 测试文件

在 `test/` 目录创建：

- `test.tex` - 本地测试文件

- `test_overleaf.tex` - Overleaf 测试文件

- `compile.bat` - 编译脚本

- `diagnose.bat` - 诊断工具

  

### 6. 质量保证和验证

  

#### 6.1 语法检查

- 检查所有 `.tex` 文件语法正确

- 确保所有 `\begin{}` 和 `\end{}` 匹配

- 验证表格格式正确

- 检查数学符号在数学模式中

  

#### 6.2 路径验证

- 确保所有 `\input{}` 引用路径正确

- 验证图片路径为 `figures/xxx`

- 检查参考文献文件路径

  

#### 6.3 编译测试

- 提供正确的编译顺序：

  ```bash

  pdflatex main.tex      # 生成 .aux 文件

  bibtex main            # 处理参考文献

  pdflatex main.tex      # 解析引用

  pdflatex main.tex      # 确保引用正确

  ```

- 说明 Overleaf 自动处理编译顺序

  

## 最佳实践和注意事项

  

### 🔧 关键技术要点

  

#### 1. 引用系统配置

```latex

% 推荐配置 - 最稳定的引用方案

\usepackage[numbers]{natbib}

\usepackage[hidelinks]{hyperref}  % 去除绿色框

\bibliographystyle{plainnat}       % 配套样式

```

  

#### 2. BibTeX 格式优化

```bibtex

% 推荐格式 - 清理空字段

@article{key2025,

  author = {Author, A. and Author, B.},

  title = {Paper Title},

  journal = {Journal Name},

  year = {2025}

  % 不要包含空的 volume、number、pages 字段

}

```

  

#### 3. 表格格式

```latex

% 推荐使用 booktabs

\begin{table}[h]

\centering

\begin{tabular}{lccc}  % 明确指定列格式

\toprule

Header1 & Header2 & Header3 & Header4 \\

\midrule

data1  & data2  & data3  & data4  \\

data5  & data6  & data7  & data8  \\

\bottomrule

\end{tabular}

\caption{Table caption}

\end{table}

```

  

### ⚠️ 常见问题预防

  

#### 1. Overleaf 兼容性

- **问题**：自定义文档类在 Overleaf 上不兼容

- **解决**：提供标准的 article 类版本

- **最佳实践**：main.tex 用于 Overleaf，main_local.tex 用于本地

  

#### 2. 引用显示问题

- **问题**：引用显示为 `[?]`

- **原因**：编译顺序不对或 BibTeX 格式错误

- **解决**：

  - 确保正确的编译顺序

  - 清理 BibTeX 文件中的空字段

  - 使用标准的 natbib + plainnat 组合

  

#### 3. 链接彩色框

- **问题**：引用和链接有绿色/红色框

- **解决**：使用 `\usepackage[hidelinks]{hyperref}`

  

#### 4. 特殊字符处理

- **问题**：`_`、`&`、`%`、`#` 等字符导致编译错误

- **解决**：

  - `_` → `\_`

  - `&` → `\&`

  - `%` → `\%`

  - `#` → `\#`

  

### 📦 文件组织最佳实践

  

#### 主目录（上传到 Overleaf）

```

✅ main.tex          # Overleaf 主文件

✅ ref.bib          # 参考文献数据库

✅ data/            # 章节目录

✅ figures/         # 图片目录

✅ README.md        # 项目说明

```

  

#### 测试目录（不上传）

```

📁 test/

    ├── 测试文件

    ├── 编译脚本

    ├── 诊断工具

    └── 详细指南

```

  

### 🎯 质量检查清单

  

#### 内容完整性

- [ ] 所有章节正确转换

- [ ] 摘要和关键词完整

- [ ] 参考文献全部转换

- [ ] 表格和公式格式正确

  

#### 技术正确性

- [ ] LaTeX 语法正确

- [ ] 引用键匹配无误

- [ ] 文件路径正确

- [ ] 编译无错误

  

#### Overleaf 准备

- [ ] main.tex 可直接上传

- [ ] ref.bib 格式标准

- [ ] 文件结构简洁

- [ ] 文档说明完善

  

## 示例调用

  

```

"将 D:\md_to_latex\md\MyPaper.md 转换为 LaTeX 工程"

"把 md 目录下的论文转换为 LaTeX 项目"

"处理 MyPaper.md 并生成支持 Overleaf 的 LaTeX 项目"

```

  

## 预期输出

  

转换完成后，用户将得到：

1. **立即可用的 Overleaf 项目**：直接上传 main.tex 和相关文件即可

2. **本地编译版本**：支持更多自定义功能

3. **完整的文档**：包含使用指南和上传说明

4. **测试工具**：帮助验证转换结果

5. **优化的引用系统**：无绿色框，引用稳定显示

  

## 相关资源

  

- **Overleaf 官方文档**：https://www.overleaf.com/learn

- **LaTeX 数学符号**：https://en.wikibooks.org/wiki/LaTeX/Mathematics

- **BibTeX 格式指南**：https://www.overleaf.com/learn/BibTeX

- **natbib 文档**：https://ctan.org/pkg/natbib