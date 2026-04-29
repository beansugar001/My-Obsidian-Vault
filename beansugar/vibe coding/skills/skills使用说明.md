# 项目结构
.claude/skills/my-awesome-skill/
├── SKILL.md           # 核心定义文件 (必填)
├── reference.md       # 详细的参考资料 (可选，按需加载)
├── examples/          # 存放 Few-shot 示例 (可选)
│   └── example-1.md
└── scripts/           # 存放该技能需要调用的脚本 (可选)
    └── validator.py
# README.md 模板
---
## 1. 基础信息
name: my-skill-name
description: 简洁明了地描述该技能的功能（Claude 靠它来判断是否自动触发）。
when_to_use: 详细描述触发场景。例如："当用户要求进行代码重构或性能优化时。"
argument-hint: "[参数1] [参数2]"
## 2. 调用控制
如果是具有副作用的操作（如部署、删除），建议设为 true，仅由你手动 / 调用
disable-model-invocation: false 
# 是否在 / 菜单中隐藏
user-invocable: true 
# 3. 运行环境配置
设为 fork 则在独立的 Subagent 中运行，不污染当前对话上下文
context: fork
agent: Plan  # 可选: Explore, Plan, general-purpose
model: claude-3-5-sonnet-20241022
effort: high # 调整思考深度 (low, medium, high, max)

# 4. 权限与工具
预先批准工具，减少询问弹窗。例如: Bash(git *), Read, Write
allowed-tools: [Read, Grep, Bash]

# 5. 动态上下文注入 (高级)
在加载 Skill 前运行命令并注入结果
env_info: !`node -v && git status --short`

---

# 🤖 角色定义
你现在是一位[角色名，如：资深架构师]。你的目标是[具体目标]。

## 📋 执行准则 (Instructions)
1. **优先检查**: 在执行任何操作前，先读取 `package.json` 或相关配置文件。
2. **安全约束**: 严禁修改 `.env` 文件。
3. **输出规范**: 使用结构化的 Markdown 表格或 Checkbox 展示进度。

## 🔄 工作流 (Workflow)
1. **分析**: 使用 `grep` 搜索 $0 中的关键字。
2. **计划**: 提出三个优化方案并解释优劣。
3. **执行**: 根据用户选择，使用 `edit_file` 进行修改。
4. **验证**: 运行对应的测试脚本。

## 💡 使用示例
- `/my-skill-name src/components/Login.tsx`
- "Claude，帮我分析一下这个模块的逻辑 $ARGUMENTS"

## 📚 附加资源
- 详细规范请参考 [reference.md](reference.md)
- 查看历史最佳实践 [examples/best_practices.md](examples/best_practices.md)