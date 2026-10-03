---
name: plan-orchestrator
description: Create and maintain an execution Plan after product and technical reviews approve a build, or for an explicitly scoped design or demo before product review. Do not use during ordinary requirement clarification or review.
---

# Plan Orchestrator

## Mandatory gate

First identify the lifecycle stage. Create a Plan only (1) after requirement review and technical review have approved a solution and before its build, or (2) after requirement clarification, before requirement review, when the user has chosen a bounded design or Demo to make. Complexity determines whether a build in either window needs a Plan; it does not advance the lifecycle stage. Requests to discuss a solution, perform research, or review requirements/technology do not trigger a Plan. A pre-review design/Demo Plan authorizes only that artifact, not full product implementation.

For every complex construction task in an allowed Plan window, create:

```text
流程管理/执行计划/<任务ID>_<任务名>/plans.md
```

The Plan is the single source of truth for execution. Use the state sequence `draft -> awaiting_review -> approved -> executing -> validating -> awaiting_acceptance -> closed`. Do not begin engineering before `approved`; a generic instruction such as “直接执行” does not bypass review for complex work.

When a Plan is first created or materially changes while `awaiting_review`, classify the current user Query as `plan_create_or_update` and register the exact conversation/turn and Plan path through `.codex/hooks/plan-disclosure-runtime.ps1 -Event Register`. If the user explicitly asks to see the complete Plan again, register `plan_redisclose`. Approval, rejection without a Plan edit, status questions, ordinary follow-ups, and unrelated Queries must not register a disclosure.

The same registered turn's final response must reproduce the complete current `plans.md` body and explicitly request approval. A path, link, summary, excerpt, or statement that the Plan exists is insufficient. Stop checks only the Plan explicitly bound to the current Query/turn; it must never scan global `awaiting_review` files or choose by modification time. The first Stop attempt reinjects that bound Plan once. If Memory also needs closeout, complete it in that same continuation so the next Stop can persist the disclosure receipt and display the Plan response.

## Required content

- `Purpose`: user result and business value.
- `Scope`: included, excluded, dependencies, modules, and delivery stage.
- `Context`: current facts, relevant paths, rules, comments, and constraints.
- `Plan of Work`: staged actions, ownership, order, migration, and rollback.
- `Validation`: checks, acceptance evidence, and substitutes for unavailable validation.
- `Progress`: timestamped state and completed, active, pending, or blocked items.
- `Decision Log`: options, chosen direction, reason, and user approval.
- `Surprises & Discoveries`: new facts, issues, risks, and resulting plan changes.
- `Outcomes & Retrospective`: delivered result, unverified or deferred work, acceptance, and lessons.

## Maintenance

Update Progress after each stage, Decision Log after each material choice, and Surprises immediately when execution differs from plan. Reconcile the Plan with task, requirement-status, issue, risk, acceptance, version, and handoff records. A partially completed Plan cannot be reported as final completion.

## Technical-design handoff

For the post-review build window, consume the approved technical design and recorded review decision produced via `technical-design-authoring`. The Plan governs engineering execution; requirements and the approved technical design govern product scope and implementation contracts. Return an unresolved technical design/review to that Skill before planning construction; preserve the existing bounded design/Demo exception.
