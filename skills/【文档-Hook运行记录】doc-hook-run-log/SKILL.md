---
name: doc-hook-run-log
description: Control 流程管理/Hook运行记录.md as a human-readable governance summary backed by the machine runtime event log. Use when Hook 生命周期事件需要人类回溯时.
---

# Hook 运行摘要 Controller

This Skill controls `流程管理/Hook运行记录.md`. Raw events remain append-only in `.codex/harness/runtime-events.jsonl`; this Markdown file provides the reviewable summary linked to user requests, tasks, Plans, decisions, and outcomes.

## Workflow

- Append entries; preserve chronology and redact secrets or raw sensitive prompts.
- Include timestamp, triggering user request or event, current state, related IDs, result, and next action.
- Reconcile summaries against machine events within the configured version/time window.
- Do not define Hook behavior or lifecycle transitions in this file; scripts and schemas govern those rules.

