# SilentAgentHub

一个人带着 AI 编程助手做产品，最常见的问题不是 AI 不会写代码，而是它做事没有章法：需求没问清就开工，换个对话就忘了上次做到哪，改了什么、为什么改、验没验证都说不清。项目越做越大，返工越来越多。

SilentAgentHub 是一套装在 Coding Agent（Codex、Claude Code 等）上的一站式工作规范插件，覆盖从**需求 → 研究分析 → 设计 → 原型 → 开发 → 测试 → 发布**的完整流程。它把一个成熟产品团队的工作方式写成 AI 能执行的规则、Skill 和 Hook，让任何一个 0-1 的想法都能按可追溯、可验证、可回滚的方式落地。

## 装上之后，AI 会怎样工作

| 阶段 | AI 的做法 | 你能看到的结果 |
|---|---|---|
| 需求 | 先澄清目标用户、场景、范围和验收标准，登记进需求池（做 / Waitlist / 不做） | `产品管理/clarification.md` 与需求池里每条需求都有编号和状态 |
| 研究分析 | 对竞品、技术、价格、政策用一手来源调研，写明"是什么、怎么用、花多少钱" | 研究记录与来源清单 |
| 设计与 Plan | 复杂工程先写 living Plan，并完整展示给你审批；批准前不动代码 | `流程管理/执行计划/<任务>/plans.md` |
| 开发 | 先找可复用的 Skill 和代码资产，再按模块规则开发 | 模块规则、复用选型记录 |
| 测试 | 按改动风险选择 smoke / 模块 / E2E / 截图验证；页面改动必须附截图 | 验证记录与截图证据 |
| 发布 | Verify（测试环境）与 Final（生产）两道门禁，生产发布须你授权，并记录回滚方案 | 版本记录、发布与回滚记录 |
| 记忆与交接 | 每轮对话自动记录需求与完成状态，跨窗口可无缝接续 | `SHORT_MEMORY.md` / `LONG_MEMORY.md` |

它有几条不可绕过的底线：不覆盖你已有的改动、不做破坏性操作、不提交密钥、未验证不说"完成"、生产和高风险操作先等你确认。

## 仓库里有什么

```text
core/          根规则：AGENTS.md（Codex）、CLAUDE.md（Claude Code）、PLANS.md（Plan 规范）
skills/        88 个已发布 Skill
  ├─ 流程与语义 Skill（34 个）   需求澄清、产品研究、Plan 编排、模块上下文、复用选型、验证、代码评审、
  │                        问题闭环、Git/环境推广、版本发布、记忆记录与收尾、知识沉淀与同步等
  └─ 文档控制 Skill（54 个，doc-*）  每份受管文档一个 Skill，负责创建、追加、字段校验和关联
harness/
  ├─ V5.2.5/     版本化 Harness 包：项目模板（Hooks、Schema、诊断工具）、manifest 与 Skill 源
  └─ overlays/mac-adaptation/  macOS 适配层与回归测试
commands/      斜杠命令：/analytics、/decision、/init-project、/version-bump
templates/     任务管理、问题流水、验收清单、版本控制等管理文档模板
```

设计上遵循"业务 Skill 负责语义 → 文档 Skill 负责留痕 → Hook/Schema 负责确定性检查"的分层：根规则只做路由和门禁，具体流程、模板和状态机都下沉到 Skill 和脚本里，避免规则膨胀和互相冲突。

## 怎么用

1. **安装根规则**：把 `core/AGENTS.md` 放到 `~/.codex/AGENTS.md`（Codex），或把 `core/CLAUDE.md` 放到 `~/.claude/CLAUDE.md`（Claude Code）；`core/PLANS.md` 放在同一目录。
2. **安装 Skill**：把 `skills/` 下的目录复制到 `~/.codex/skills/`（或 Claude Code 的 `~/.claude/skills/`）。目录名开头的【中文】只是方便浏览，安装时请去掉，用后面的英文名作目录名（例如 `【需求澄清】requirement-clarification` 装成 `requirement-clarification`）：Harness 的 macOS 适配层和 Skill 之间的互相引用都按英文目录定位。
3. **安装 Harness 包**：把 `harness/V5.2.5` 放到 `~/.codex/harness/V5.2.5`，并新建 `~/.codex/harness/current.json` 指向它（字段见 `project-initialization` Skill）。macOS 用户再按 `harness/overlays/mac-adaptation/Apply-Overlay.ps1` 应用适配层（需要 PowerShell 7）。
4. **初始化项目**：在新项目里对 AI 说"初始化项目"，`project-initialization` 会建立 Router、管理文档、记忆文件和项目级 Hooks。之后直接提需求即可。

规则正文以中文编写。部分 Skill（如支付宝网页支付部署、小红书检索、Google Drive 快照）面向特定场景，按需使用。

## 关于本仓库

本仓库整理自作者日常使用的 Harness 运行态（根规则 V5.2.6（AGENTS 与 CLAUDE 一致），Harness 包 V5.2.5），已移除认证配置、个人记忆、运行日志、自动化任务、第三方插件缓存和第三方 Skill，并去除个人路径信息。由 [SilentLake-Tech-SkillHub](https://github.com/SilentLake-Tech-SkillHub) 维护。

## 技术方案与评审

`technical-design-authoring`把已确认需求和当前系统事实写成可实施的技术方案，并提供技术评审入口；每项需求有实现、交付与验收去向。技术方案评审后再制定工程执行Plan。使用说明见[Skill入口](skills/【技术方案与评审】technical-design-authoring/SKILL.md)，结构、实际使用及副本校验见[验证记录](validation/technical-design-authoring-1.0.0/README.md)。
