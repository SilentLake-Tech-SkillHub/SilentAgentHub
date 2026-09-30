---
name: skill-library-router
description: Discover and select existing system, project, plugin, or knowledge-hub Skills before creating a new one. Use when a task mentions Skills, when initialization chooses capabilities, or when overlapping Skill candidates could duplicate behavior.
---

# Skill Library Router

1. Search in precedence order: explicitly named Skill, project Skills, system Skills, installed plugin Skills, configured knowledge-hub library.
2. Read the complete selected `SKILL.md` and every required reference before taking task actions.
3. Compare trigger, scope, outputs, permissions, dependencies, freshness, and validation. Record selection and rejection reasons.
4. Reuse or extend a compatible Skill. Create a new Skill only when the capability boundary is genuinely distinct.
5. If multiple Skills apply, state the order and use the smallest set that covers the task.
6. Validate every changed package and update Router or inventory status.

Do not copy plugin or system Skills into the project merely to list them. Refer to external dependencies by canonical name and keep project Skills project-specific.
