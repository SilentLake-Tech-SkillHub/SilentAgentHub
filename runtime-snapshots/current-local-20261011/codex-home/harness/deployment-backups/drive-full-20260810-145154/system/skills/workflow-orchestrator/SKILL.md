---
name: workflow-orchestrator
description: Orchestrate the complete Harness lifecycle from requirement classification through approved Plan, engineering, multi-level validation, user acceptance, Git/environment promotion, and archival. Use for non-trivial delivery work and lifecycle recovery.
---

# Workflow Orchestrator

## Workflow

1. Classify the request with `requirement-clarification`; use `doc-clarification` to append the intake lifecycle to `产品管理/clarification.md`, then route the result by stable ID to the requirement pool, Decision, Plan, research, or task.
2. Preserve the sanitized prompt and current conversation state in project SHORT_MEMORY. Session routing may load only the matching activity block; Long Memory and historical ledgers remain cold.
3. Determine complexity. Complex engineering must call `plan-orchestrator`, create the task `plans.md`, show the first Plan to the user, and wait for explicit approval.
4. Route approved work through domain Skills, reusable assets, and required plugins. Each module must load its local rules first.
5. Run validation in applicable layers: smoke, module/unit, integration/E2E, AI eval, browser screenshot, and test-environment closed loop.
6. At Verify, call `code-review-closeout` and `git-environment-promotion`; update Validation, CodeReview, ChangeOwnership, GitPromotion, task, issue, risk, and version evidence.
7. At Final, require user acceptance and explicit production authorization, then promote Git/environment, run production verification, update release and rollback evidence, and archive the lifecycle.
8. At Stop, close the current Memory turn against formal evidence, synchronize active ledgers, archive configured terminal rows through verified transactions, and keep history cold.

## Machine governance

- Lifecycle states and allowed transitions come from `.codex/harness/lifecycle-state-machine.json`.
- The transition script validates state changes; Markdown does not define the state machine.
- Skill/Hook raw runtime evidence is append-only JSONL. Human Markdown ledgers preserve the timestamp, user request or event, called Skills/plugins, current state, linked records, result, and next action needed for review.

## Boundaries

- Do not bypass Plan review for complex engineering.
- Do not let a Hook commit, push, deploy, or approve.
- Do not promote production without explicit user authorization, registered destination, rollback path, and passing evidence.
