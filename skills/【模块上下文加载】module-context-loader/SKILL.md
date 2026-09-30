---
name: module-context-loader
description: Load the minimum complete context for a specific engineering module before research, design, coding, debugging, deployment, or operations. Use whenever work targets a module or when module ownership and boundaries are unclear.
---

# Module Context Loader

1. Resolve the module through Router and `代码管理/模块规划.md`.
2. Read the module rule, README, architecture section, repository status, active Plan, open tasks, issues, risks, acceptance criteria, tests, deployment notes, and recent debug or operations records.
3. Summarize module goal, user-visible outcome, boundaries, inputs, outputs, dependencies, write paths, validation, delivery standard, and known failure modes.
4. Check for uncommitted user changes and avoid overlapping edits.
5. If the module rule is missing or incomplete, log a problem and use `project-initialization/references/module-rule-contract.md` to prepare a candidate before engineering.
6. Use `project-initialization/references/source-layout.md` only for new modules; do not restructure an established repository merely to match a template.

Return a small context packet and links to source records. Do not copy entire documents into the task context.
