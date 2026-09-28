---
name: doc-plan
description: Control each task-specific plans.md under 流程管理/执行计划. Use for complex engineering, user-requested plans, phased delivery, or initialization audits.
---

# 执行计划 Controller

This Skill exclusively controls `流程管理/执行计划/<任务ID>_<任务名>/plans.md`. It creates, validates, and updates this artifact without taking over the semantic work of requirement analysis, planning, decision-making, engineering, or approval.

## Trigger

- 复杂工程、用户要求 Plan 或分阶段推进。
- `project-initialization` selects this controller from `.codex/harness/document-controllers.json` when the artifact is required for the project type or enabled module.

## Contract

- Purpose: 创建并维护 living Plan；首次计划必须用户 review 批准后才能工程执行。
- `plans.md` 的 `## State` 段必须包含一行 `State: <状态>`，独占一行、以 `State:` 开头。该行是 `plan-disclosure-runtime.ps1` 判定 `awaiting_review` 的唯一依据；写成列表项会使 Register 抛出 `plan-not-awaiting-review`。
- Plan 首次创建、实质修改或用户明确要求重发全文时，必须由语义 Skill 先将当前用户 Query/turn 与唯一 Plan path/hash 注册到 `.codex/hooks/plan-disclosure-runtime.ps1`；审批、状态询问、普通追问和无关 Query 不得注册。
- 注册轮最终回复必须完整输出 `plans.md` 正文并显式请求审批；Stop 只校验当前 Query 显式绑定的 Plan 并一次性注入，绝不扫描全局 `awaiting_review` 或按修改时间猜测。若 Memory 同时待收口，必须在同一次 continuation 完成，确保最终 Plan 回答不被下一道 Stop 门禁隐藏。
- Use `assets/template.md` as the initial structure; preserve newer user content and append the smallest valid delta.
- Validate the required headings, stable identifiers, links to related records, and current status before returning.
- Update `ROUTER.md` through `doc-router` only when this file is created, moved, renamed, or retired.
- Never duplicate another artifact's facts. Link by requirement, task, decision, issue, version, or release ID.
- Runtime Skill/Hook events belong in `.codex/harness/runtime-events.jsonl`, not this Markdown file.

## Boundaries

- Keep this Markdown artifact as human-readable governance evidence. Its controller or semantic Skill owns validation and transitions; the file records timestamp, triggering user request, called Skills/plugins, current status, related IDs, result, and next route.
- Do not create a Markdown state-machine definition. Raw Hook/Skill telemetry remains in the machine event log; this artifact keeps only calls needed to explain its own lifecycle.
- Do not approve a Plan, decision, release, or acceptance on the user's behalf.
- If a required field is unknown, mark it explicitly and route the gap to the responsible semantic Skill.
