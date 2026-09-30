---
name: doc-product-acceptance
description: Control 产品管理/产品验收标准.md. Use when 需求批准进入建设；用户效果或验收口径变化，or when project-initialization creates or audits this artifact.
---

# 产品验收标准 Controller

This Skill exclusively controls `产品管理/产品验收标准.md`. It creates, validates, and updates this artifact without taking over the semantic work of requirement analysis, planning, decision-making, engineering, or approval.

## Trigger

- 需求批准进入建设；用户效果或验收口径变化。
- `project-initialization` selects this controller from `.codex/harness/document-controllers.json` when the artifact is required for the project type or enabled module.

## Contract

- Purpose: 维护用户可见效果、关键路径、异常路径和产品验收条件。
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
