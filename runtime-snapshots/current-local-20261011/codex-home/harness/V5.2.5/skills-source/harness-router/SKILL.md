---
name: harness-router
description: Resolve the actual project root and load the minimum relevant rules, plans, records, Skills, and module context. Use at session start, after changing workspace, when paths conflict, or before work spanning multiple governance areas.
---

# Harness Router

## Route

1. Resolve Git root, workspace root, and user-declared root. If they differ, record all three and use the user-declared project boundary unless unsafe.
2. Read the system-level `AGENTS.md`, then the project `ROUTER.md`, then only the applicable module rule.
3. Load the active task, approved `plans.md`, open problems and risks, acceptance criteria, version identity, relevant Skills, and only the matching active SHORT_MEMORY block.
4. Verify every routed path exists or is an explicit placeholder. Prefer the newest file only after the version-window check confirms it belongs to the same artifact lineage.
5. Surface conflicts instead of silently choosing: rule precedence, two active Plans, mismatched task status, stale Router entry, or inaccessible knowledge mount.
6. Keep LONG_MEMORY and `流程管理/历史记录库/` cold. Read either only after an active miss plus explicit history/recovery need or a stable history ID trace.
7. Return a concise context packet containing root, task, stage, plan state, module, required Skills, write targets, validation, and blockers.

Do not load all management files by default. Router is an index and dispatcher, not another copy of their content.

## Technical-design context

When the request concerns implementation design or technical review, locate the current requirements, design/review records and registered controllers, then route to `technical-design-authoring`. A technical-document request or status/path clarification does not by itself create or load a new engineering Plan.
