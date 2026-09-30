---
name: doc-knowledge-hub
description: Control 知识管理/研究知识中台链接.md. Use when 初始化或中台位置、权限变化，or when project-initialization creates or audits this artifact.
---

# 知识中台挂载 Controller

This Skill exclusively controls `知识管理/研究知识中台链接.md`. It creates, validates, and updates this artifact without taking over the semantic work of requirement analysis, planning, decision-making, engineering, or approval.

## Trigger

- 初始化或中台位置、权限变化。
- `project-initialization` selects this controller from `.codex/harness/document-controllers.json` when the artifact is required for the project type or enabled module.

## Contract

- Purpose: 仅记录挂载位置、用途、权限边界和最近校验；路径未知可占位。
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
