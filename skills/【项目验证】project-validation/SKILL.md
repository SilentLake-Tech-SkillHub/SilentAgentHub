---
name: project-validation
description: Select and run proportionate validation for project, code, data, AI Agent, document, browser, deployment, Skill, Hook, or management-record changes. Use after implementation and before reporting a stage complete or ready for acceptance.
---

# Project Validation

## Select checks

1. Read the Plan Validation section, module rule, build files, test configuration, CI workflows, and acceptance criteria.
2. Prefer the project's own commands: `make check`, `make test`, `make lint`, `make typecheck`, `make eval`; otherwise infer from package, Python, language, or CI configuration.
3. Add domain checks: browser paths and console for UI; SQL and data-quality checks for data; evals for prompt, Agent, tool, retrieval, memory, guardrail, model, rubric, or golden-case changes; parser and representative events for Hooks; `quick_validate.py` for Skills; render-and-readback for documents.
4. Run the narrowest checks first, then the acceptance path and relevant regression scope.
5. Capture command, environment, time, result, evidence path, and skipped or unavailable checks.
6. Update Plan, issue, risk, acceptance, task, and version records consistently.

## Validation profiles

Select exactly one profile before running checks. Record the profile and reason.

- `readonly`: questions, status, diagnosis, and readback with no current-turn mutation. Run only targeted readback; do not validate all Skills, Hooks, schemas, manifests, install, or rollback.
- `simple_change`: a low-risk local change with a narrow impact. Parse changed scripts and run targeted smoke/tests only.
- `complex_engineering`: multi-file or behavior changes. Validate changed Skills, changed Hook parsers, targeted E2E, and the relevant regression E2E. Do not run production packaging checks unless releasing.
- `production_release`: only when constructing or promoting a production package. Add all-Skill validation, all-Hook parsing, all schemas, manifest Hash, isolated installation, production smoke, and rollback rehearsal.

Never describe “81 Skill definitions statically validated” as “81 Skills invoked.” Separate semantic Skill usage, static validation targets, Hook scripts executed, and files hashed in every report.

For repeated validation, reuse unchanged results within the same commit/worktree Hash and version window. One automatic retry is allowed; after that, use a documented alternative or report the blocker.

Use `scripts/check_harness.ps1` for a quick structural audit. Never translate “file exists” into “feature verified”; state verified, failed, unverified, and substitute checks separately.
