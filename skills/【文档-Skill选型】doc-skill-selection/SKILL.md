---
name: doc-skill-selection
description: Control 知识管理/Skill选型记录.md. Use when 任务需要选择、组合或拒绝 Skills，or when project-initialization creates or audits this artifact.
---

# Skill 选型 Controller

This Skill exclusively controls `知识管理/Skill选型记录.md`. It creates, validates, and updates this artifact without taking over the semantic work of requirement analysis, planning, decision-making, engineering, or approval.

## Trigger

- 任务需要选择、组合或拒绝 Skills。
- `project-initialization` selects this controller from `.codex/harness/document-controllers.json` when the artifact is required for the project type or enabled module.

## Contract

- Purpose: 记录候选、适配、风险、最终选择和结果。
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
