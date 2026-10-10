# Source layout reference

This is the complete directory-responsibility reference for initialization. It is selectable, not a mandatory tree: create only directories needed by enabled modules and the chosen stack. Do not copy this table or tree into the system-level `AGENTS.md`.

```text
代码管理/代码仓/
├── src/
│   ├── app/              # 页面、路由、布局、入口
│   ├── components/       # 可复用 UI 与业务组件
│   ├── hooks/            # 前端状态逻辑
│   ├── styles/           # 样式、主题、动画
│   ├── services/         # 前端 API 或跨端服务
│   ├── server/
│   │   ├── routes/       # HTTP 路由定义
│   │   ├── controllers/  # 请求与响应处理
│   │   ├── services/     # 后端业务逻辑与流程编排
│   │   ├── repositories/ # 数据库访问与持久化逻辑
│   │   ├── models/       # 数据模型、DTO 与类型定义
│   │   ├── middlewares/  # 鉴权、校验、限流与错误处理
│   │   └── config/       # 环境变量、数据库、日志与第三方配置
│   ├── agents/           # Agent 编排
│   ├── tools/            # Agent 工具
│   ├── prompts/          # Prompt 模板
│   ├── memory/           # 会话与用户记忆
│   ├── guardrails/       # 安全与权限检查
│   ├── retrieval/        # RAG、切块、检索、重排
│   ├── observability/    # 日志、trace、成本和指标
│   └── utils/
├── tests/
├── evals/
├── scripts/
└── docs/
```

## Directory responsibility contract

| Directory | Responsibility |
|---|---|
| `src/app/` | 页面、路由、布局和应用入口。 |
| `src/components/` | 可复用 UI 组件和业务展示组件。 |
| `src/hooks/` | 前端状态逻辑和 React hooks。 |
| `src/styles/` | 全局样式、主题变量和动画。 |
| `src/services/` | 前端 API 调用或跨端业务服务。 |
| `src/server/routes/` | HTTP 路由定义。 |
| `src/server/controllers/` | 请求与响应处理。 |
| `src/server/services/` | 后端业务逻辑和流程编排。 |
| `src/server/repositories/` | 数据库访问和持久化逻辑。 |
| `src/server/models/` | 数据模型、DTO 和类型定义。 |
| `src/server/middlewares/` | 鉴权、校验、限流和错误处理。 |
| `src/server/config/` | 环境变量、数据库、日志和第三方配置。 |
| `src/agents/` | Agent 编排、计划、执行和评审逻辑。 |
| `src/tools/` | Agent 可调用的搜索、SQL、浏览器、地图和外部 API 等工具。 |
| `src/prompts/` | Prompt 模板；不得把大型 Prompt 硬编码在业务代码中。 |
| `src/memory/` | 会话记忆、用户偏好、摘要和向量记忆。 |
| `src/guardrails/` | 安全检查、权限检查、PII 过滤和风控规则。 |
| `src/retrieval/` | RAG、切块、embedding、向量检索、query rewrite 和 rerank。 |
| `src/observability/` | 日志、trace、token usage、cost、metrics 和 error reporting。 |
| `src/utils/` | 通用工具函数。 |
| `tests/` | 单元测试、集成测试和端到端测试。 |
| `evals/` | AI 行为评估、golden cases、metrics 和 judge rubric。 |
| `scripts/` | 初始化、运行、验证和报告生成脚本。 |
| `docs/` | 工程文档、API 文档、部署文档和操作手册。 |

## Machine-readable contract

1. Copy `assets/source-layout.manifest.json` to `.codex/harness/source-layout.json` only when a code module is enabled, then tailor `base_path`, `entries`, `coverage_roots`, and exclusions to the actual repository.
2. Set an entry to `enabled: true` only when that directory belongs to the current stage. Every enabled entry must exist and have a non-empty `role`.
3. Register coherent existing custom directories instead of renaming them merely to match this reference. Add a precise role for each custom entry.
4. `coverage_roots` tells the integrity checker which directory levels must be completely registered. An actual immediate child under a coverage root fails validation when it is neither declared nor excluded.
5. Use `coverage_exclusions` only for generated, dependency, cache, or tool-owned directories. Do not use it to hide an undocumented business or engineering directory.
6. Set `.codex/harness/index.json` `sourceLayoutRequired` to `true` when code is in scope. Keep it `false` for research-only or documentation-only projects that intentionally have no source-layout contract.

Selection rules:

1. Start from the product goal and module plan, not from this tree.
2. Reuse an existing repository layout when it is coherent.
3. Record every created source area and its owner in `.codex/harness/source-layout.json`; summarize module ownership in `代码管理/模块规划.md` without copying this full responsibility table.
4. Keep large prompts outside business code and require evals when prompts, agents, tools, retrieval, memory, guardrails, model config, judge rubrics, or golden cases change.
5. If a directory is not needed in the current stage, leave it absent and record the reason; empty scaffolding is not progress.
