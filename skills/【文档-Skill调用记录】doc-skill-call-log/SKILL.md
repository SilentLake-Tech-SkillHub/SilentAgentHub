---
name: doc-skill-call-log
description: Control 流程管理/Skill调用记录.md as a human-readable governance summary backed by the machine runtime event log. Use when 任务调用、切换、失败或跳过 Skill 时.
---

# Skill 调用摘要 Controller

This Skill controls `流程管理/Skill调用记录.md`. Raw events remain append-only in `.codex/harness/runtime-events.jsonl`; this Markdown file provides the reviewable summary linked to user requests, tasks, Plans, decisions, and outcomes.

## Workflow

- Append entries; preserve chronology and redact secrets or raw sensitive prompts.
- Include timestamp, triggering user request or event, current state, related IDs, result, and next action.
- Reconcile summaries against machine events within the configured version/time window.
- Do not define Hook behavior or lifecycle transitions in this file; scripts and schemas govern those rules.

