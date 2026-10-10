# Project structure contract

Create only missing artifacts that are relevant to the current project. Preserve compatible existing names by recording a Router mapping instead of duplicating content.

```text
项目根/
├── ROUTER.md                         # 人与 Agent 的最小入口及路径映射
├── README.md                         # 项目结果、使用方法、当前状态
├── ARCHITECTURE.md                   # 项目架构唯一事实源
├── MEMORY.md                         # 项目 Memory 规则
├── SHORT_MEMORY.md                   # 未关闭 conversation，最近 5 轮
├── LONG_MEMORY.md                    # 已关闭 conversation，默认 cold
├── .gitignore
├── .env.example
├── 流程管理/
│   ├── 任务管理.md
│   ├── 执行计划/<任务ID>_<任务名>/plans.md
│   ├── 需求与范围变更记录.md          # 已进入开发的需求状态
│   ├── 决策记录.md
│   ├── 问题流水.md
│   ├── debug记录.md
│   ├── 风险阻塞清单.md
│   ├── 验收清单.md
│   ├── 运维记录.md
│   ├── 规则补充待审.md
│   ├── 版本控制.md
│   ├── 上下文交接记录.md
│   └── 历史记录库/INDEX.md
├── 产品管理/
│   ├── clarification.md              # Skill 调用与澄清流水
│   ├── 需求变更记录.md               # 做 / Waitlist / 不做 的需求池
│   ├── 需求素材/
│   ├── 研究记录.md
│   ├── 建设框架.md
│   └── 产品验收.md
├── 代码管理/
│   ├── 模块规划.md
│   ├── 可复用模块选型记录.md
│   ├── 代码仓/
│   ├── 测试/
│   ├── evals/
│   └── 部署/
├── 知识管理/
│   ├── 项目知识索引.md
│   ├── 沉淀候选.md
│   ├── 同步记录.md
│   ├── KnowledgeRouter.md
│   ├── LLM-Wiki使用与运维.md
│   └── 研发中台使用与同步.md
└── .agents/skills/                   # 仅放项目专用 Skills
```

The system-level `AGENTS.md` lives under the Codex root, not under this tree. Add a project `AGENTS.md` only for project-specific constraints that Router and module rules cannot express.

The three Memory files are project assets: initialization creates them, Router mounts them, and project Git tracks them. Only `.codex/harness/memory-locks/` and unfinished temporary transactions are ignored.

Do not maintain another writable architecture body under `代码管理/`; module plans and rules link to root `ARCHITECTURE.md` sections and decision IDs.

`产品管理/需求变更记录.md` is the clarification pool: what will be done, placed on the Waitlist, or rejected. `流程管理/需求与范围变更记录.md` starts only after a requirement enters development and tracks statuses such as building, completed, pending validation, and accepted.
