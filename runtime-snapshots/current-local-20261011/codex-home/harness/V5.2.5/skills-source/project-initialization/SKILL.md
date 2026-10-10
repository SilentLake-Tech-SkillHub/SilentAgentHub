---
name: project-initialization
description: Initialize or repair a project harness when entering a new or structurally uncertain workspace, when Router or governance records are missing, or when the user asks to initialize, scaffold, reorganize, or establish project rules. This skill owns the detailed project tree, source-layout choices, module-rule contract, Git checks, and initialization acceptance so the system-level AGENTS.md stays concise.
---

# Project Initialization

Use this Skill for project-level initialization. The system-level `AGENTS.md` is global policy; do not copy it into every project. A project `AGENTS.md` is optional and may contain only project-specific additions.

## Required references

Read all five references before changing a workspace:

- `references/project-structure.md`
- `references/source-layout.md`
- `references/module-rule-contract.md`
- `references/initialization-acceptance.md`
- `references/document-controller-registry.md`

When a code module is enabled, also copy and tailor `assets/source-layout.manifest.json` to `.codex/harness/source-layout.json`. This manifest is the project-specific machine contract used by the Stop integrity checker; the detailed directory responsibilities remain in this Skill, not in the system-level `AGENTS.md`.

## Workflow

1. Resolve the actual project root and inspect existing rules, records, repositories, local changes, and reusable assets.
2. Determine whether initialization, repair, or no action is needed. Preserve newer user files and never replace an established layout without recording the migration decision.
3. When `$CODEX_HOME/harness/current.json` exists, run `scripts/install-harness-assets.ps1 -Root <project-root>` before document initialization. It installs only missing project-level Hooks, Harness assets, and approved on-demand diagnostics from the versioned project template. Existing conflicting files and version-declared retired assets are reported and preserved; use `-Repair` only after user approval, and require the script to back up every conflicting or retired file before replacement/removal. Diagnostics under `tools/diagnostics/` are manual tools and must never be registered as production Hooks.
4. Load `.codex/harness/document-controllers.json`; select only the artifacts required by the project goal, stage, and enabled modules. Invoke the registered atomic `doc-*` controller for every selected Markdown artifact. Every document must preserve the human ledger fields defined in `references/document-controller-registry.md`.
5. Always create project-root `MEMORY.md`, `SHORT_MEMORY.md`, and `LONG_MEMORY.md` through their controllers, register all three in `ROUTER.md`, and keep them in the project Git repository. Install the Memory policy, index, Hook scripts, transaction folders, and transient-lock ignores; never redirect these files to `$CODEX_HOME`.
6. Clarify the project goal, user-visible result, delivery stage, enabled modules, deferred modules, acceptance criteria, and repository boundaries.
7. Select a source layout from `references/source-layout.md`; create only enabled module directories. Record every enabled or existing governed directory in `.codex/harness/source-layout.json`, with a non-empty responsibility.
8. For every enabled module, create or repair its local rule using `references/module-rule-contract.md`.
9. Check the storage boundary, Git, `.gitignore`, `.env.example`, and sensitive-file exclusions. If a durable project is under the Windows system drive, record the risk and prepare a user-approved move or non-system-drive root before Git initialization; never move it silently. Do not create nested Git repositories without an approved decision.
10. Create and maintain `产品管理/clarification.md` through `doc-clarification`; `requirement-clarification` performs semantic clarification and the ledger records time, user request, called Skills, current state, output routes, result, and next step.
11. Create `流程管理/历史记录库/INDEX.md` and the approved retention policy. Automatic migration is enabled only after the installed production Hooks pass fixture and project initialization acceptance; activity ledgers keep open records and history remains cold.
12. When knowledge management is enabled, create `知识管理/KnowledgeRouter.md`, `LLM-Wiki使用与运维.md`, and `研发中台使用与同步.md`; keep `<RND_HUB_ROOT>` and LLM Wiki identity as explicit placeholders until configured.
13. Register paths in `ROUTER.md` through `doc-router`. Router stores path, purpose, responsible Skill, status, and last check only; a missing hub mount may remain a labelled placeholder.
14. Set `sourceLayoutRequired: true` in `.codex/harness/index.json` when a code module is enabled. Install the query-bound Plan disclosure runtime, empty disclosure state, schema, and E2E fixture from the approved production package; never seed a new project by scanning existing `awaiting_review` Plans. Run source-layout, document-controller, lifecycle, Memory, history, and Plan-disclosure integrity checkers plus every check in `references/initialization-acceptance.md`.
15. Report the initialized result, selected documents/controllers, enabled modules, deferred scope, validation evidence, and remaining decisions in product language.

## Boundaries

- Do not create all possible engineering modules by default.
- Do not require project-level `AGENTS.md` or `CLAUDE.md` mirrors unless that project explicitly adopts them.
- Do not duplicate `ARCHITECTURE.md`; root `ARCHITECTURE.md` is the project architecture single source of truth and code-management records only link to it.
- Do not treat directory creation as initialization completion.
- Do not put the lifecycle state machine, templates, or workflow instructions into `ROUTER.md`; keep governance logic in Skills, schemas, and scripts while Markdown keeps human-readable evidence.
- Do not change the system-level harness without user approval; use only the approved version recorded in `$CODEX_HOME/harness/current.json`.
- Do not ignore or relocate project-root Memory files; only lock files and unfinished temporary transactions are transient.
