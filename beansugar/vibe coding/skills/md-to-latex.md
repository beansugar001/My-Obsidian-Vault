---
name: md-to-latex
description: 将 Markdown 格式的学术论文转换为完整的、可编译的 LaTeX 工程（符合 ACM 标准）
---

## 触发条件（TRIGGER WHEN）
- 用户有一个 `.md` 格式的学术论文初稿，需要转换为 LaTeX 格式
- 用户提到 "将 MD 转为 LaTeX"、"创建 LaTeX 论文工程"、"生成学术 LaTeX 项目" 等类似需求
- 用户需要生成符合 ACM 标准的学术论文格式
- 用户请求将 Markdown 论文组织为可编译的 LaTeX 目录结构

## 输入要求
- **必需**：一个 Markdown 格式的论文文件（.md）
- **建议**：文件应包含标准的章节结构（使用 `#`、`##` 标题）
- **建议**：文件末尾包含参考文献列表（References）

## 执行步骤

### 1. 环境准备
1. 确认当前工作目录
2. 搜索并下载 ACM 官方 LaTeX 模板文件：
   - 使用 `curl` 或 `wget` 下载 `acmart.cls`
   - 下载 `ACM-Reference-Format.bst` 参考文献样式文件
3. 验证模板文件下载成功

### 2. 创建标准目录结构
在项目根目录下创建以下结构：

```
project_root/
├── main.tex                    # 主入口文件
├── references.bib              # BibTeX 参考文献数据库
├── acmart.cls                  # ACM 模板类文件
├── ACM-Reference-Format.bst    # 参考文献样式文件
├── data/                       # 分章节内容目录
│   ├── 01_intro.tex           # 引言
│   ├── 02_related_work.tex    # 相关工作
│   ├── 03_method.tex          # 方法
│   ├── 04_experiments.tex     # 实验
│   ├── 05_discussion.tex      # 讨论
│   └── 06_conclusion.tex      # 结论
└── figures/                    # 图片存放目录
```

### 3. 内容解析与转换
1. **读取并解析 MD 文件**
   - 识别章节标题（`#`、`##`、`###`）
   - 提取每个章节的内容

2. **转换章节到独立文件**
   - 将每个主要章节内容写入 `data/` 下对应的 `.tex` 文件
   - **标题转换规则**：
     - `# 标题` → `\section{标题}`
     - `## 标题` → `\subsection{标题}`
     - `### 标题` → `\subsubsection{标题}`

3. **格式转换**
   - **表格**：MD 表格 → LaTeX `table` 环境
   - **数学公式**：
     - 行内公式：`$公式$` → `$公式$`（保持不变或转换为 `\(公式\)`）
     - 独立公式：`$$公式$$` → `\[公式\]` 或 `equation` 环境
   - **列表**：转换为 `itemize` 或 `enumerate` 环境
   - **代码块**：转换为 `verbatim` 或 `listings` 环境
   - **图片**：提取图片引用，在 `figures/` 创建占位符

### 4. 参考文献处理
1. 提取 MD 文件末尾的 References 列表
2. 解析每条参考文献信息（作者、标题、年份、出处等）
3. 生成标准的 BibTeX 条目格式
4. 写入 `references.bib` 文件
5. 在主文件中配置 `\bibliography{references}` 和 `\bibliographystyle{ACM-Reference-Format}`

### 5. 主文件组装（main.tex）
创建 `main.tex` 文件，包含：

```latex
\documentclass[sigconf,anonymous]{acmart}

% 包配置
\usepackage{graphicx}
\usepackage{amsmath}
\usepackage{booktabs}

% 元数据
\title{论文标题}
\author{作者信息}
\date{\today}

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
\bibliography{references}
\bibliographystyle{ACM-Reference-Format}

\end{document}
```

### 6. 验证与测试
1. 检查所有 `.tex` 文件语法正确
2. 确保所有 `\input` 引用路径正确
3. 提示用户使用 `pdflatex` 或 `xelatex` 编译测试
4. 如有编译错误，提供修复建议

## 注意事项
- **编码问题**：确保所有文件使用 UTF-8 编码
- **特殊字符**：转义 LaTeX 特殊字符（如 `_`、`&`、`%`）
- **图片路径**：更新图片引用路径为 `figures/xxx`
- **表格格式**：LaTeX 表格需要手动指定列格式（如 `l c r`）
- **数学符号**：确保所有数学符号在数学模式中

## 示例调用
```
"将这个 paper.md 转换为 LaTeX 工程"
"创建符合 ACM 标准的 LaTeX 论文项目"
"把我的 Markdown 论文转为可编译的 LaTeX 格式"
```

## 相关资源
- ACM 官方模板：https://www.acm.org/publications/proceedings-template
- LaTeX 数学符号：https://en.wikibooks.org/wiki/LaTeX/Mathematics
